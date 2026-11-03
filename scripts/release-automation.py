#!/usr/bin/env python3
"""Prepare monthly patch PRs and request releases only after successful main CI.

Uses GitHub's own token and explicit workflow_dispatch calls: pushes/merges made
with GITHUB_TOKEN do not themselves start push/pull_request workflows.
"""
import argparse
import base64
from datetime import date, datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import time
from urllib.parse import quote
from zoneinfo import ZoneInfo


STABLE = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")


def monthly_period(now=None):
    now = now or datetime.now(timezone.utc)
    return now.astimezone(ZoneInfo('Europe/Lisbon')).strftime('%Y-%m')


def version(value):
    if not STABLE.fullmatch(value):
        raise ValueError("Expected a stable X.Y.Z version")
    return tuple(map(int, value.split('.')))


def api(repository, path, method="GET", payload=None, missing=False):
    command = ["gh", "api", f"repos/{repository}/{path}", "--method", method]
    if payload is not None:
        command += ["--input", "-"]
    result = subprocess.run(command, input=json.dumps(payload) if payload is not None else None,
                            capture_output=True, text=True)
    if result.returncode:
        if missing and "(HTTP 404)" in result.stderr:
            return None
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else None


def published_versions(repository):
    result = []
    page = 1
    while True:
        releases = api(repository, f"releases?per_page=100&page={page}")
        for release in releases:
            tag = release['tag_name']
            if (not release['draft'] and not release['prerelease'] and tag.startswith('v')
                    and STABLE.fullmatch(tag[1:])):
                result.append(tag[1:])
        if len(releases) < 100:
            return sorted(set(result), key=version)
        page += 1


def previous_version(current, published):
    prior = [item for item in published if version(item) < version(current)]
    if not prior:
        raise ValueError("No previous published stable release for package comparison")
    return max(prior, key=version)


def main_revision(repository):
    return api(repository, "git/ref/heads/main")['object']['sha']


def dispatch_ci(repository, branch):
    api(repository, "actions/workflows/ci.yml/dispatches", "POST", {'ref': branch})


def start_release(repository, revision, root=Path('.')):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("Expected a full commit SHA")
    if subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip() != revision:
        raise ValueError("Checkout does not match the tested revision")
    if main_revision(repository) != revision:
        print("main advanced after this CI run; the newer revision must pass its own CI.")
        return
    current = (root / 'VERSION').read_text().strip()
    version(current)
    published = published_versions(repository)
    if current in published:
        print(f"{current} is already published; no release requested.")
        return
    if published and version(current) <= version(published[-1]):
        raise ValueError("Automatic releases must be newer than the latest published version")
    previous_version(current, published)
    tag = f'v{current}'
    reference = api(repository, f'git/ref/tags/{tag}', missing=True)
    if reference is None:
        api(repository, 'git/refs', 'POST', {'ref': f'refs/tags/{tag}', 'sha': revision})
    else:
        target = reference['object']
        for _ in range(8):
            if target['type'] == 'commit':
                break
            if target['type'] != 'tag':
                raise ValueError("Release tag does not identify a commit")
            target = api(repository, f"git/tags/{target['sha']}")['object']
        if target['type'] != 'commit' or target['sha'] != revision:
            raise ValueError("Existing immutable tag identifies another revision; recover that release or use a new version")
    # Tag creation with GITHUB_TOKEN does not trigger Release's push event.
    api(repository, 'actions/workflows/release.yml/dispatches', 'POST',
        {'ref': 'main', 'inputs': {'tag': tag, 'repair_notes': 'false'}})
    print(f"Requested Release for {tag} at {revision}.")


def monthly_files(root, current, period):
    date.fromisoformat(period + '-01')
    major, minor, patch = version(current)
    updated = f'{major}.{minor}.{patch + 1}'
    files = {'VERSION': updated + '\n'}
    replacements = {
        'Dockerfile': (f'ARG VERSION={current}', f'ARG VERSION={updated}'),
        'docker-bake.hcl': (f'default = "{current}"', f'default = "{updated}"'),
        'tests/lib.sh': (f'VERSION:-{current}', f'VERSION:-{updated}'),
    }
    for name, (before, after) in replacements.items():
        text = (root / name).read_text()
        if text.count(before) != 1:
            raise ValueError(f'Expected exactly one version default in {name}')
        files[name] = text.replace(before, after)
    readme = (root / 'README.md').read_text()
    if not readme.startswith(f'# Production {current}\n'):
        raise ValueError('README version does not match VERSION')
    files['README.md'] = readme.replace(current, updated)
    changelog = (root / 'CHANGELOG.md').read_text()
    if f'\n## {updated} ' in changelog:
        raise ValueError('The next patch already has a changelog entry')
    heading = changelog.index('\n## ')
    entry = (f'\n## {updated} - Unreleased\n\n### Maintenance\n\n'
             f'- Monthly package refresh for {period}, based on {current}. Rebuild all six variants without cache.\n'
             '- Publish only after native amd64/arm64 tests, scans and signature verification pass.\n'
             '- Attach the source comparison and exact old/new package inventories to the release.\n')
    files['CHANGELOG.md'] = changelog[:heading] + entry + changelog[heading:]
    files['RELEASE.md'] = (
        f'# Production {updated} — Monthly package refresh\n\n'
        f'Monthly maintenance for {period}, based on Production {current}.\n\n'
        'Rebuild Generic and Laravel for PHP 8.3, 8.4 and 8.5 on amd64 and ARM64 '
        'without cache to install the available Alpine package updates.\n\n'
        'The release includes a source comparison and per-image/per-architecture package '
        'tables with previous and new versions, additions and removals. The tables record '
        'actual changes; package versions alone do not establish vulnerability remediation.\n\n'
        'Publication requires intensive runtime tests, real PHP/Laravel applications, '
        'vulnerability scans, SBOM/provenance checks and signature verification. '
        'Versioned tags remain immutable; eligible stable aliases move only after validation.\n')
    files['.github/monthly-release.json'] = json.dumps(
        dict(period=period, version=updated, previous_version=current), indent=2) + '\n'
    return updated, files


def read_marker(repository, ref):
    item = api(repository, 'contents/.github/monthly-release.json' +
               '?ref=' + quote(ref, safe=''), missing=True)
    return json.loads(base64.b64decode(item['content'])) if item else None


def await_ci(repository, branch, revision, timeout):
    path = ('actions/workflows/ci.yml/runs?event=workflow_dispatch&per_page=100&branch='
            + quote(branch, safe=''))
    existing = {run['id'] for run in api(repository, path)['workflow_runs']}
    dispatch_ci(repository, branch)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        runs = [run for run in api(repository, path)['workflow_runs']
                if run['id'] not in existing and run['head_sha'] == revision]
        if runs:
            run = max(runs, key=lambda item: item['id'])
            if run['status'] == 'completed':
                if run['conclusion'] != 'success':
                    raise RuntimeError(f"Monthly CI did not pass: {run['html_url']}")
                return
        time.sleep(30)
    raise TimeoutError('Monthly CI did not finish; leave the PR open and retain current public images')


def monthly_release(repository, period, timeout, root=Path('.')):
    if not re.fullmatch(r'[0-9]{4}-(0[1-9]|1[0-2])', period):
        raise ValueError('Expected YYYY-MM')
    date.fromisoformat(period + '-01')
    main = main_revision(repository)
    if subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip() != main:
        raise ValueError('main changed since checkout; rerun the monthly workflow')
    marker = read_marker(repository, 'main')
    if marker and marker['period'] >= period:
        if marker['period'] == period and marker['version'] not in published_versions(repository):
            dispatch_ci(repository, 'main')
            print('Monthly patch is already integrated; requested main CI to resume publication.')
        else:
            print('This month already has a patch; no new version created.')
        return
    current = (root / 'VERSION').read_text().strip()
    published = published_versions(repository)
    if not published or current != published[-1]:
        raise ValueError('Publish the current main VERSION before preparing another monthly patch')
    branch = 'maintenance/monthly-' + period
    reference = api(repository, 'git/ref/heads/' + branch, missing=True)
    if reference is None:
        updated, files = monthly_files(root, current, period)
        base = api(repository, 'git/commits/' + main)
        tree = api(repository, 'git/trees', 'POST', {'base_tree': base['tree']['sha'], 'tree': [
            dict(path=name, mode='100755' if (root / name).exists() and
                 (root / name).stat().st_mode & 0o111 else '100644', type='blob', content=content)
            for name, content in files.items()]})
        commit = api(repository, 'git/commits', 'POST', {
            'message': f'chore: monthly package refresh {period} ({updated})',
            'tree': tree['sha'], 'parents': [main]})
        revision = commit['sha']
        api(repository, 'git/refs', 'POST', {'ref': 'refs/heads/' + branch, 'sha': revision})
    else:
        revision = reference['object']['sha']
        marker = read_marker(repository, branch)
        if not marker or marker['period'] != period or marker['previous_version'] != current:
            raise ValueError('Existing monthly branch has unexpected metadata; review it before retrying')
        updated = marker['version']
        if version(updated) != (*version(current)[:2], version(current)[2] + 1):
            raise ValueError('Existing monthly branch is not the expected patch release')
    pulls = api(repository, 'pulls?state=all&base=main&head=' + quote(repository.split('/')[0] + ':' + branch, safe=''))
    if pulls:
        pull = pulls[0]
        if pull['state'] != 'open':
            raise ValueError('The monthly PR is already closed; inspect its merge/publication before retrying')
    else:
        pull = api(repository, 'pulls', 'POST', {
            'title': f'Monthly package refresh {period}: Production {updated}',
            'head': branch, 'base': 'main',
            'body': ('Prepare the monthly patch release from the published main version.\n\n'
                     'The monthly workflow explicitly runs intensive CI for this exact commit, '
                     'then requests a protected merge. Required reviews and branch protections '
                     'remain in force. Main CI and native release validation must pass before '
                     'public image tags move. Package/source comparisons are generated from the '
                     'actual release candidates.\n')})
    print(f"Monthly pull request: {pull['html_url']}", flush=True)
    await_ci(repository, branch, revision, timeout)
    pull = api(repository, f"pulls/{pull['number']}")
    if (pull['head']['sha'] != revision or pull['base']['ref'] != 'main'
            or pull['head']['repo']['full_name'] != repository or pull['draft']):
        raise ValueError('Monthly PR changed after testing; refusing to merge')
    # No administrator bypass or force push: required checks/reviews still apply.
    result = api(repository, f"pulls/{pull['number']}/merge", 'PUT',
                 {'sha': revision, 'merge_method': 'squash'})
    if not result['merged']:
        raise RuntimeError('Monthly merge was blocked: ' + result.get('message', 'unknown reason'))
    if main_revision(repository) != result['sha']:
        raise ValueError('main advanced after the monthly merge; its newer CI must run before publication')
    dispatch_ci(repository, 'main')
    print('Monthly patch merged; requested main CI, which will request the release only after passing.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', default=os.environ.get('GITHUB_REPOSITORY'))
    sub = parser.add_subparsers(dest='command', required=True)
    start = sub.add_parser('start')
    start.add_argument('--revision', required=True)
    previous = sub.add_parser('previous')
    previous.add_argument('--version', required=True)
    monthly = sub.add_parser('monthly')
    monthly.add_argument('--period', default=monthly_period())
    monthly.add_argument('--timeout', type=int, default=6600)
    args = parser.parse_args()
    if not args.repository or not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', args.repository):
        parser.error('Provide --repository OWNER/REPO or GITHUB_REPOSITORY')
    if args.command == 'start':
        start_release(args.repository, args.revision)
    elif args.command == 'previous':
        print('previous_version=' + previous_version(args.version, published_versions(args.repository)))
    else:
        if args.timeout <= 0:
            parser.error('--timeout must be positive')
        monthly_release(args.repository, args.period, args.timeout)


if __name__ == '__main__':
    main()
