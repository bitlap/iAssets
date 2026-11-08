#!/usr/bin/env python3
"""Check the shipped widget catalogs and execute its Swift locale resolver."""
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from sync_native_l10n import ROOT, catalog


class NativeWidgetLocalizationTests(unittest.TestCase):
    def test_extension_declares_every_app_language(self):
        expected = set()
        for path in (ROOT / 'lib/l10n').glob('strings_*.dart'):
            code = path.stem.removeprefix('strings_')
            expected.add({
                'zh': 'zh-Hans', 'zh_hant': 'zh-Hant',
                'pt_br': 'pt-BR', 'pt_pt': 'pt-PT',
            }.get(code, code))
        with (ROOT / 'ios/AssetsWidget/Info.plist').open('rb') as file:
            languages = plistlib.load(file)['CFBundleLocalizations']
        self.assertEqual(len(languages), 33)
        self.assertEqual(set(languages), expected)

    @unittest.skipUnless(sys.platform == 'darwin', 'Swift Foundation requires macOS')
    def test_swift_resolves_languages_and_matches_app_catalogs(self):
        widget = (ROOT / 'ios/AssetsWidget/AssetsWidget.swift').read_text()
        words = widget[widget.index('private enum WidgetWords {'):widget.index('private struct AssetWidgetView:')]
        snapshot = (ROOT / 'ios/Shared/AssetWidgetSnapshot.swift').read_text().split('enum AssetWidgetSnapshotStore {')[0]
        checks = r'''
let date = Date(timeIntervalSince1970: 1793885158)
func snapshot(_ language: String) -> AssetWidgetSnapshot {
  AssetWidgetSnapshot(schema: 1, currency: "USD", language: language,
    updatedAtMillis: Int64(date.timeIntervalSince1970 * 1000), incomplete: false,
    hidden: false, total: nil, stocks: nil, crypto: nil, other: nil)
}
for language in WidgetWords.words["total"]!.keys {
  assert(WidgetWords.language(snapshot(language), locale: Locale(identifier: "en_US")) == language)
  let locale = ["zh": "zh_CN", "zh_Hant": "zh_Hant_TW" ][language] ?? language
  assert(WidgetWords.language(nil, locale: Locale(identifier: locale)) == language)
  assert(!snapshot(language).formattedUpdateTime(language: language).isEmpty)
}
for (locale, language) in ["zh_HK": "zh_Hant", "zh_MO": "zh_Hant", "zh_Hans_TW": "zh",
                          "pt_AO": "pt_BR", "pt_PT": "pt_PT", "tl_PH": "fil", "no_NO": "nb",
                          "iw_IL": "he", "in_ID": "id", "zz_ZZ": "en"] {
  assert(WidgetWords.language(nil, locale: Locale(identifier: locale)) == language, locale)
}
assert(WidgetWords.language(snapshot("unknown"), locale: Locale(identifier: "de_DE")) == "de")
assert(WidgetWords.text("total", "unknown") == "Total assets")
let output = try! JSONSerialization.data(withJSONObject: WidgetWords.words, options: [.sortedKeys])
print(String(data: output, encoding: .utf8)!)
'''
        with tempfile.TemporaryDirectory(prefix='iassets-native-l10n-') as directory:
            path = Path(directory) / 'main.swift'
            path.write_text(snapshot + words + checks)
            result = subprocess.run(['xcrun', 'swift', str(path)], check=True, capture_output=True, text=True)
        actual = json.loads(result.stdout)
        expected = {}
        for path in (ROOT / 'lib/l10n').glob('strings_*.dart'):
            code = path.stem.removeprefix('strings_')
            code = {'zh_hant': 'zh_Hant', 'pt_br': 'pt_BR', 'pt_pt': 'pt_PT'}.get(code, code)
            for key, value in catalog(path).items():
                if key.startswith('widget'):
                    name = key[6].lower() + key[7:]
                    expected.setdefault(name, {})[code] = value
        self.assertEqual(actual, expected)


if __name__ == '__main__':
    unittest.main()
