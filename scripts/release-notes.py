#!/usr/bin/env python3
"""Describe the source diff from the previous published stable release."""
import argparse
import json
from pathlib import Path
import re
import subprocess


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root).decode()


def source_changes(root, repository, previous, current, revision):
    for value in (previous, current):
        if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', value):
            raise ValueError('Expected stable X.Y.Z versions')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Expected OWNER/REPO')
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Expected a complete revision SHA')
    selected = git(root, 'rev-parse', f'v{current}^{{commit}}').strip()
    if selected != revision:
        raise ValueError('The release tag does not match the selected revision')
    before = git(root, 'rev-parse', f'v{previous}^{{commit}}').strip()
    subprocess.run(['git', 'merge-base', '--is-ancestor', before, revision], cwd=root, check=True)
    records = git(root, 'diff', '--no-renames', '--name-status', '-z', before, revision).split('\0')
    files = [dict(change=records[i], path=records[i + 1]) for i in range(0, len(records) - 1, 2)]
    log = git(root, 'log', '--format=%H%x09%s', f'{before}..{revision}')
    commits = [dict(zip(('sha', 'subject'), line.split('\t', 1))) for line in log.splitlines()]
    return dict(repository=repository, previous_version=previous, version=current,
                previous_revision=before, revision=revision, files=files, commits=commits)


def code(value):
    return '`' + value.replace('`', "'").replace('\n', ' ').replace('\r', ' ') + '`'


def markdown(report):
    repository = report['repository']
    previous, current = report['previous_version'], report['version']
    lines = ['## Source changes', '',
             f'[Full comparison: v{previous} → v{current}](https://github.com/{repository}/compare/v{previous}...v{current})', '',
             'The release summary above describes functionality. The following list records the actual source changes.', '']
    for status, label in (('A', 'Added files'), ('M', 'Modified files'), ('D', 'Removed files')):
        paths = [item['path'] for item in report['files'] if item['change'] == status]
        if paths:
            lines += [f'### {label}', ''] + ['- ' + code(path) for path in paths] + ['']
    if not report['files']:
        lines += ['No source file changes; rebuilt packages are listed in the package comparison.', '']
    if report['commits']:
        lines += ['### Included commits', '']
        for commit in report['commits'][:100]:
            lines.append(f"- [{commit['sha'][:12]}](https://github.com/{repository}/commit/{commit['sha']}) {code(commit['subject'])}")
        if len(report['commits']) > 100:
            lines.append('- See the full comparison for the remaining commits.')
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', required=True)
    parser.add_argument('--previous-version', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--output', type=Path, default=Path('release-changes'))
    args = parser.parse_args()
    report = source_changes(Path('.'), args.repository, args.previous_version, args.version, args.revision)
    Path(str(args.output) + '.json').write_text(json.dumps(report, indent=2) + '\n')
    Path(str(args.output) + '.md').write_text(markdown(report))


if __name__ == '__main__':
    main()
