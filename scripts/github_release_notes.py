#!/usr/bin/env python3
"""Render Chinese and English GitHub notes from the full multilingual changelog."""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GITHUB_LANGUAGES = ('简体中文', '繁體中文', 'English')


def render(version):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Expected a numeric release version')
    source = (ROOT / 'changelog' / f'{version}.md').read_text()
    if not source.startswith(f'# {version}\n'):
        raise ValueError('Changelog version heading does not match')
    parts = re.split(r'^## (.+)\n', source, flags=re.M)
    headings, bodies = parts[1::2], parts[2::2]
    if len(headings) != len(set(headings)):
        raise ValueError('Duplicate language headings')
    sections = dict(zip(headings, bodies))
    result = [f'# {version}']
    for language in GITHUB_LANGUAGES:
        body = sections.get(language, '').strip()
        if not re.search(r'^- .+', body, flags=re.M):
            raise ValueError(f'Missing GitHub release notes: {language}')
        result.append(f'## {language}\n\n{body}')
    return '\n\n'.join(result) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        notes = render(args.version)
        if args.output:
            args.output.write_text(notes)
        else:
            print(notes, end='')
    except (ValueError, OSError) as error:
        parser.exit(1, f'GitHub release notes failed: {error}\n')


if __name__ == '__main__':
    main()
