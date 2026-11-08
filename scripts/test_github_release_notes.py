#!/usr/bin/env python3
"""Check that GitHub notes remain bilingual without losing store translations."""
import re
import tempfile
import unittest
from pathlib import Path

import github_release_notes as renderer


class GitHubReleaseNotesTests(unittest.TestCase):
    def setUp(self):
        self.original = renderer.ROOT
        self.temp = tempfile.TemporaryDirectory(prefix='iassets-github-notes-')
        renderer.ROOT = Path(self.temp.name)
        (renderer.ROOT / 'changelog').mkdir()
        self.path = renderer.ROOT / 'changelog/2.2.0.md'
        self.source = (self.original / 'changelog/2.2.0.md').read_text()
        self.path.write_text(self.source)

    def tearDown(self):
        renderer.ROOT = self.original
        self.temp.cleanup()

    def test_only_chinese_and_english_are_published(self):
        result = renderer.render('2.2.0')
        self.assertEqual(re.findall(r'^## (.+)$', result, re.M), list(renderer.GITHUB_LANGUAGES))
        for language in renderer.GITHUB_LANGUAGES:
            expected = self.source.split(f'## {language}\n', 1)[1].split('\n## ', 1)[0].strip()
            actual = result.split(f'## {language}\n', 1)[1].split('\n## ', 1)[0].strip()
            self.assertEqual(actual, expected)
        self.assertEqual(len(re.findall(r'^- ', result, re.M)), 24)
        self.assertEqual(self.path.read_text(), self.source)

    def test_missing_english_is_rejected(self):
        self.path.write_text(self.source.replace('## English\n', '## Other\n'))
        with self.assertRaisesRegex(ValueError, 'Missing GitHub release notes: English'):
            renderer.render('2.2.0')

    def test_duplicate_language_is_rejected(self):
        self.path.write_text(self.source + '\n## English\n\n- Duplicate\n')
        with self.assertRaisesRegex(ValueError, 'Duplicate language'):
            renderer.render('2.2.0')

    def test_wrong_version_heading_is_rejected(self):
        self.path.write_text(self.source.replace('# 2.2.0\n', '# 2.1.0\n', 1))
        with self.assertRaisesRegex(ValueError, 'version heading'):
            renderer.render('2.2.0')


if __name__ == '__main__':
    unittest.main()
