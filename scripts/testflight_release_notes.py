#!/usr/bin/env python3
"""Render per-build TestFlight notes with localized test focus and limitations."""
import argparse
import re
from pathlib import Path

from check_release_notes import languages

ROOT = Path(__file__).resolve().parent.parent


def render(version, build, language):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Expected a numeric release version')
    if not re.fullmatch(r'[1-9]\d*', str(build)):
        raise ValueError('Expected a positive integer build number')
    registry = dict(languages())
    if language not in registry:
        raise ValueError('Language is not in the app registry')
    source = (ROOT / 'changelog' / f'{version}.md').read_text()
    if not source.startswith(f'# {version}\n'):
        raise ValueError('Changelog version heading does not match')
    parts = re.split(r'^## (.+)\n', source, flags=re.M)
    headings, texts = parts[1::2], parts[2::2]
    if len(headings) != len(set(headings)):
        raise ValueError('Duplicate language headings')
    notes = dict(zip(headings, texts)).get(registry[language], '').strip()
    if not re.search(r'^- .+', notes, flags=re.M):
        raise ValueError('Missing localized changelog section')
    focus = (ROOT / 'changelog' / 'testflight' / version / f'{language}.txt').read_text().strip()
    if (len(re.findall(r'^• .+', focus, re.M)) != 2 or
            'TestFlight' not in focus or
            'https://github.com/bitlap/iAssets/issues' not in focus):
        raise ValueError('Missing test focus, limitations or feedback link')
    result = f'{version} ({build})\n\n{notes}\n\n{focus}\n'
    if len(result.strip()) > 4000:
        raise ValueError('TestFlight notes exceed 4000 characters')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--build', required=True)
    parser.add_argument('--language', required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        result = render(args.version, args.build, args.language)
        if args.output:
            args.output.write_text(result)
        else:
            print(result, end='')
    except (ValueError, OSError) as error:
        parser.exit(1, f'TestFlight release notes failed: {error}\n')


if __name__ == '__main__':
    main()
