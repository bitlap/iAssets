#!/usr/bin/env python3
"""Regression checks for language omissions in release documentation."""
import contextlib
import io
import shutil
import tempfile
import unittest
from pathlib import Path

import check_release_notes as checker


class ReleaseNotesTests(unittest.TestCase):
    def setUp(self):
        self.original = checker.ROOT
        self.temp = tempfile.TemporaryDirectory(prefix='iassets-release-docs-')
        self.root = Path(self.temp.name)
        for name in ['lib/l10n/l10n.dart', 'pubspec.yaml']:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(self.original / name, target)
        shutil.copytree(self.original / 'changelog', self.root / 'changelog')
        checker.ROOT = self.root
        self.notes = self.root / 'changelog/2.2.0.md'

    def tearDown(self):
        checker.ROOT = self.original
        self.temp.cleanup()

    def test_current_release_covers_the_complete_registry(self):
        with contextlib.redirect_stdout(io.StringIO()):
            checker.validate('2.2.0')

    def test_three_languages_cannot_pass_as_full_coverage(self):
        self.notes.write_text(self.notes.read_text().split('## 日本語', 1)[0])
        with self.assertRaisesRegex(ValueError, 'Language headings'):
            checker.validate('2.2.0')

    def test_english_fallback_is_not_a_translation(self):
        source = self.notes.read_text()
        english = source.split('## English\n', 1)[1].split('\n## ', 1)[0]
        german = source.split('## Deutsch\n', 1)[1].split('\n## ', 1)[0]
        self.notes.write_text(source.replace(german, english))
        with self.assertRaisesRegex(ValueError, 'copied English'):
            checker.validate('2.2.0')

    def test_missing_product_copy_is_rejected(self):
        checker.product_path('ja').unlink()
        with self.assertRaises(OSError):
            checker.validate('2.2.0')

    def test_missing_terms_link_is_rejected(self):
        path = checker.product_path('ja')
        path.write_text(path.read_text().replace('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/', ''))
        with self.assertRaisesRegex(ValueError, 'missing EULA'):
            checker.validate('2.2.0')

    def test_copied_english_product_description_is_rejected(self):
        checker.product_path('ja').write_text(checker.product_path('en').read_text())
        with self.assertRaisesRegex(ValueError, 'copied English product description'):
            checker.validate('2.2.0')

    def test_incomplete_product_template_is_rejected(self):
        path = checker.product_path('ja')
        path.write_text(path.read_text().replace('• ', '', 1))
        with self.assertRaisesRegex(ValueError, '8 aligned product features'):
            checker.validate('2.2.0')

    def test_missing_sync_topic_is_rejected(self):
        path = checker.product_path('ja')
        path.write_text(path.read_text().replace('iCloud', 'Cloud'))
        with self.assertRaisesRegex(ValueError, 'missing product topic'):
            checker.validate('2.2.0')

    def test_missing_privacy_link_is_rejected(self):
        path = checker.product_path('ja')
        path.write_text(path.read_text().replace('https://bitlap.org/iAssets-privacy/', ''))
        with self.assertRaisesRegex(ValueError, 'missing privacy link'):
            checker.validate('2.2.0')

    def test_mismatched_entry_count_is_rejected(self):
        source = self.notes.read_text().replace('## 日本語\n', '## 日本語\n\n- 追加項目\n', 1)
        self.notes.write_text(source)
        with self.assertRaisesRegex(ValueError, 'Entry counts differ'):
            checker.validate('2.2.0')


if __name__ == '__main__':
    unittest.main()
