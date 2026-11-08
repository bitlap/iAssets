#!/usr/bin/env python3
"""Validate current release notes and product copy against the app registry."""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def languages():
    source = (ROOT / 'lib/l10n/l10n.dart').read_text()
    constants = dict(re.findall(r"static const String (\w+) = '([^']+)';", source))
    registry = source.split('static const languages =', 1)[1].split(
        'static const translations =', 1)[0]
    rows = re.findall(r"(\w+|'[^']+'):\s*\(\s*name: '([^']+)'", registry)
    if not rows:
        raise ValueError('Cannot read the app language registry')
    return [(constants.get(key, key.strip("'")), name) for key, name in rows]


def product_path(code):
    return ROOT / 'changelog' / 'app_store' / f'{code}.txt'


def validate(version):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Expected a numeric release version, such as 2.2.0')
    path = ROOT / 'changelog' / f'{version}.md'
    source = path.read_text()
    if not source.startswith(f'# {version}\n'):
        raise ValueError(f'{path.name}: version heading does not match')
    sections = re.split(r'^## (.+)\n', source, flags=re.M)
    headings, texts = sections[1::2], sections[2::2]
    expected = languages()
    if headings != [name for _, name in expected]:
        missing = set(name for _, name in expected) - set(headings)
        extra = set(headings) - set(name for _, name in expected)
        raise ValueError(f'Language headings/order differ from registry; missing={sorted(missing)}, extra={sorted(extra)}')
    counts = []
    english = texts[[code for code, _ in expected].index('en')].strip()
    for (code, name), text in zip(expected, texts):
        items = re.findall(r'^- (.+)$', text, re.M)
        if not items or any(not item.strip() for item in items):
            raise ValueError(f'{name}: missing update entries')
        if re.search(r'No changes|\bTODO\b|\bTBD\b|ZXQ', text, re.I):
            raise ValueError(f'{name}: placeholder text')
        if code != 'en' and text.strip() == english:
            raise ValueError(f'{name}: copied English fallback is not a translation')
        counts.append(len(items))
        product = product_path(code)
        copy = product.read_text().strip()
        if not copy.startswith('iAssets') or len(copy) > 4000:
            raise ValueError(f'{product.relative_to(ROOT)}: invalid/oversized product copy')
        if code != 'en' and copy == product_path('en').read_text().strip():
            raise ValueError(f'{product.relative_to(ROOT)}: copied English product description')
        bullets = re.findall(r'^• (.+)$', copy, re.M)
        if len(bullets) != 8:
            raise ValueError(f'{product.relative_to(ROOT)}: expected 8 aligned product features')
        for index, markers in {1: ('API',), 4: ('Face ID', 'Touch ID'),
                               5: ('iCloud',), 6: (str(len(expected)),), 7: ('Pro',)}.items():
            if any(marker not in bullets[index] for marker in markers):
                raise ValueError(f'{product.relative_to(ROOT)}: missing product topic at entry {index + 1}')
        if not any(name in bullets[1] for name in ('Binance', '币安', '幣安')):
            raise ValueError(f'{product.relative_to(ROOT)}: missing Binance topic')
        if 'https://bitlap.org/iAssets-privacy/' not in copy:
            raise ValueError(f'{product.relative_to(ROOT)}: missing privacy link')
        if 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/' not in copy:
            raise ValueError(f'{product.relative_to(ROOT)}: missing EULA link')
        if 'https://github.com/bitlap/iAssets' not in copy:
            raise ValueError(f'{product.relative_to(ROOT)}: missing repository link')
        if re.search(r'\{\w+\}|ZXQ|\bTODO\b|\bTBD\b', copy):
            raise ValueError(f'{product.relative_to(ROOT)}: unresolved placeholder')
    if len(set(counts)) != 1:
        raise ValueError(f'Entry counts differ by language: {counts}')
    print(f'{version}: {len(expected)} languages, {counts[0]} entries each; all product-copy files validated.')
    print('Structural validation only; translation quality and platform publishing need separate verification.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', help='Current release version; defaults to pubspec.yaml')
    args = parser.parse_args()
    version = args.version
    if version is None:
        match = re.search(r'^version:\s*(\d+\.\d+\.\d+)',
                          (ROOT / 'pubspec.yaml').read_text(), re.M)
        if not match:
            parser.error('Cannot read pubspec.yaml version')
        version = match.group(1)
    try:
        validate(version)
    except (ValueError, OSError) as error:
        parser.exit(1, f'Release documentation check failed: {error}\n')


if __name__ == '__main__':
    main()
