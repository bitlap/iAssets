#!/usr/bin/env python3
"""Regression checks for localized, build-specific TestFlight metadata."""
import tempfile
import unittest
from pathlib import Path

import testflight_release_notes as renderer


class TestFlightReleaseNotesTests(unittest.TestCase):
    def test_every_language_has_notes_for_both_current_builds(self):
        for code, name in renderer.languages():
            for build in ['10', '22']:
                with self.subTest(language=code, build=build):
                    result = renderer.render('2.2.0', build, code)
                    self.assertTrue(result.startswith(f'2.2.0 ({build})\n'))
                    source = (renderer.ROOT / 'changelog/2.2.0.md').read_text()
                    section = source.split(f'## {name}\n', 1)[1].split('\n## ', 1)[0].strip()
                    self.assertIn(section, result)
                    self.assertIn('TestFlight', result)
                    self.assertLessEqual(len(result.strip()), 4000)

    def test_invalid_language_and_build_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'registry'):
            renderer.render('2.2.0', '22', '../en')
        with self.assertRaisesRegex(ValueError, 'build number'):
            renderer.render('2.2.0', '0', 'en')

    def test_missing_test_focus_is_rejected(self):
        original = renderer.ROOT
        with tempfile.TemporaryDirectory() as temp:
            renderer.ROOT = Path(temp)
            try:
                target = renderer.ROOT / 'changelog/2.2.0.md'
                target.parent.mkdir()
                target.write_text((original / 'changelog/2.2.0.md').read_text())
                with self.assertRaises(OSError):
                    renderer.render('2.2.0', '22', 'en')
            finally:
                renderer.ROOT = original

    def test_oversized_test_instructions_are_rejected(self):
        original = renderer.ROOT
        with tempfile.TemporaryDirectory() as temp:
            renderer.ROOT = Path(temp)
            try:
                (renderer.ROOT / 'changelog').mkdir()
                (renderer.ROOT / 'changelog/2.2.0.md').write_text((original / 'changelog/2.2.0.md').read_text())
                target = renderer.ROOT / 'changelog/testflight/2.2.0/en.txt'
                target.parent.mkdir(parents=True)
                target.write_text((original / 'changelog/testflight/2.2.0/en.txt').read_text() + 'x' * 4000)
                with self.assertRaisesRegex(ValueError, '4000'):
                    renderer.render('2.2.0', '22', 'en')
            finally:
                renderer.ROOT = original


if __name__ == '__main__':
    unittest.main()
