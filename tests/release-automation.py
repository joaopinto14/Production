#!/usr/bin/env python3
"""Exercise monthly/release failure gates without registry or repository writes."""
import base64
from datetime import datetime
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('automation', ROOT / 'scripts/release-automation.py')
automation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(automation)
spec = importlib.util.spec_from_file_location('notes', ROOT / 'scripts/release-notes.py')
notes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notes)
spec = importlib.util.spec_from_file_location('settings', ROOT / 'scripts/configure-repository.py')
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)
MAIN, CANDIDATE, MERGE = 'a' * 40, 'b' * 40, 'c' * 40
REPO = 'owner/production'


def fixture(root):
    for name, content in {
        'VERSION': '2.0.4\n', 'Dockerfile': 'ARG VERSION=2.0.4\n',
        'docker-bake.hcl': 'variable "VERSION" {\n default = "2.0.4"\n}\n',
        'tests/lib.sh': '#!/bin/sh\nTEST_VERSION="${VERSION:-2.0.4}"\n',
        'README.md': '# Production 2.0.4\nimage:2.0.4-php8.5\n',
        'CHANGELOG.md': '# Changelog\n\n## 2.0.4 - Published\n\nOriginal changes.\n',
    }.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    (root / 'tests/lib.sh').chmod(0o755)


class PolicyTests(unittest.TestCase):
    def test_monthly_period_follows_lisbon_at_midnight_in_summer_and_winter(self):
        for instant, expected in (
                ('2026-06-30T22:59:59+00:00', '2026-06'),
                ('2026-06-30T23:00:00+00:00', '2026-07'),
                ('2026-12-31T23:00:00+00:00', '2026-12'),
                ('2027-01-01T00:00:00+00:00', '2027-01')):
            with self.subTest(instant=instant):
                self.assertEqual(automation.monthly_period(datetime.fromisoformat(instant)), expected)

    def test_next_patch_updates_defaults_and_preserves_history_without_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            updated, files = automation.monthly_files(root, '2.0.4', '2026-12')
            self.assertEqual(updated, '2.0.5')
            self.assertEqual(files['VERSION'], '2.0.5\n')
            self.assertIn('ARG VERSION=2.0.5', files['Dockerfile'])
            self.assertIn('default = "2.0.5"', files['docker-bake.hcl'])
            self.assertIn('VERSION:-2.0.5', files['tests/lib.sh'])
            self.assertIn('image:2.0.5-php8.5', files['README.md'])
            self.assertIn('## 2.0.4 - Published\n\nOriginal changes.', files['CHANGELOG.md'])
            self.assertEqual(json.loads(files['.github/monthly-release.json']),
                             dict(period='2026-12', version='2.0.5', previous_version='2.0.4'))
            self.assertEqual((root / 'VERSION').read_text(), '2.0.4\n')
            self.assertFalse((root / '.github/monthly-release.json').exists())

    def test_mismatched_source_defaults_stop_preparation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture(root)
            (root / 'Dockerfile').write_text('ARG VERSION=2.0.3\n')
            with self.assertRaisesRegex(ValueError, 'exactly one'):
                automation.monthly_files(root, '2.0.4', '2026-12')

    def test_previous_version_is_numeric_and_published_not_an_unreleased_tag(self):
        self.assertEqual(automation.previous_version('2.0.11', ['2.0.2', '2.0.9', '2.0.10']), '2.0.10')
        with self.assertRaises(ValueError):
            automation.previous_version('2.0.4', ['2.0.4', '2.1.0'])
        for value in ('2.0.4-rc.1', 'v2.0.4', '02.0.4', '2.0.4\n'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                automation.version(value)

    def test_drafts_prereleases_and_non_version_tags_are_excluded(self):
        releases = [dict(tag_name='v2.0.4', draft=False, prerelease=False),
                    dict(tag_name='v2.0.5', draft=True, prerelease=False),
                    dict(tag_name='v2.1.0', draft=False, prerelease=True),
                    dict(tag_name='other', draft=False, prerelease=False)]
        with patch.object(automation, 'api', return_value=releases):
            self.assertEqual(automation.published_versions(REPO), ['2.0.4'])

    def test_only_explicit_404_is_treated_as_absent(self):
        for error in ('gh: Not Found (HTTP 404)', 'gh: unauthorized (HTTP 401)', 'connection timeout'):
            result = subprocess.CompletedProcess([], 1, '', error)
            with self.subTest(error=error), patch.object(automation.subprocess, 'run', return_value=result):
                if '(HTTP 404)' in error:
                    self.assertIsNone(automation.api(REPO, 'git/ref/tags/v2.0.5', missing=True))
                else:
                    with self.assertRaises(RuntimeError):
                        automation.api(REPO, 'git/ref/tags/v2.0.5', missing=True)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'VERSION').write_text('2.0.5\n')
        for name, value in (('main_revision', MAIN), ('published_versions', ['2.0.4'])):
            mock = patch.object(automation, name, return_value=value)
            mock.start()
            self.addCleanup(mock.stop)
        mock = patch.object(automation.subprocess, 'check_output', return_value=MAIN + '\n')
        mock.start()
        self.addCleanup(mock.stop)

    def test_new_tag_uses_tested_revision_and_dispatches_explicitly(self):
        with patch.object(automation, 'api', return_value=None) as api:
            automation.start_release(REPO, MAIN, self.root)
        writes = [(call.args[1], call.args[2], call.args[3]) for call in api.call_args_list if len(call.args) > 2]
        self.assertEqual(writes[0], ('git/refs', 'POST', {'ref': 'refs/tags/v2.0.5', 'sha': MAIN}))
        self.assertEqual(writes[1], ('actions/workflows/release.yml/dispatches', 'POST',
                                    {'ref': 'main', 'inputs': {'tag': 'v2.0.5', 'repair_notes': 'false'}}))

    def test_prepare_continues_in_the_same_workflow_without_dispatching_another_run(self):
        with patch.object(automation, 'api', return_value=None) as api:
            result = automation.start_release(REPO, MAIN, self.root, dispatch=False)
        self.assertEqual(result, dict(tag='v2.0.5', revision=MAIN))
        writes = [call.args for call in api.call_args_list if len(call.args) > 2]
        self.assertEqual(writes, [(REPO, 'git/refs', 'POST', {'ref': 'refs/tags/v2.0.5', 'sha': MAIN})])

    def test_prepare_outputs_the_original_source_and_leaves_skipped_runs_empty(self):
        for result in (dict(tag='v2.0.5', revision=CANDIDATE), None):
            output = self.root / 'output'
            output.write_text('')
            with self.subTest(result=result), patch.object(sys, 'argv', [
                    'release-automation.py', '--repository', REPO, 'prepare',
                    '--revision', MAIN, '--output', str(output)]), \
                    patch.object(automation, 'start_release', return_value=result) as start:
                automation.main()
            start.assert_called_once_with(REPO, MAIN, dispatch=False)
            self.assertEqual(output.read_text(), f'tag=v2.0.5\nrevision={CANDIDATE}\n' if result else '')

    def test_published_version_and_superseded_ci_never_dispatch(self):
        for name, value in (('published_versions', ['2.0.4', '2.0.5']), ('main_revision', MERGE)):
            with self.subTest(name=name), patch.object(automation, name, return_value=value), \
                    patch.object(automation, 'api') as api:
                automation.start_release(REPO, MAIN, self.root)
                api.assert_not_called()

    def test_conflicting_existing_tag_is_never_moved_or_rebuilt(self):
        with patch.object(automation, 'api', side_effect=[
                {'object': {'type': 'commit', 'sha': CANDIDATE}},
                {'status': 'diverged', 'merge_base_commit': {'sha': MERGE}}]) as api:
            with self.assertRaisesRegex(ValueError, 'immutable tag'):
                automation.start_release(REPO, MAIN, self.root)
        self.assertEqual(api.call_count, 2)
        self.assertTrue(all(len(call.args) == 2 for call in api.call_args_list))

    def test_older_tag_on_main_resumes_original_source_without_moving_it(self):
        for annotated in (False, True):
            responses = ([{'object': {'type': 'tag', 'sha': MERGE}}] if annotated else []) + [
                {'object': {'type': 'commit', 'sha': CANDIDATE}},
                {'status': 'ahead', 'merge_base_commit': {'sha': CANDIDATE}},
                {'content': base64.b64encode(b'2.0.5\n').decode()}, None]
            with self.subTest(annotated=annotated), patch.object(automation, 'api', side_effect=responses) as api:
                automation.start_release(REPO, MAIN, self.root)
            reads = [call.args[1] for call in api.call_args_list if len(call.args) == 2]
            self.assertIn(f'compare/{CANDIDATE}...{MAIN}', reads)
            self.assertIn('contents/VERSION?ref=' + CANDIDATE, reads)
            writes = [call.args for call in api.call_args_list if len(call.args) > 2]
            self.assertEqual(writes, [(REPO, 'actions/workflows/release.yml/dispatches', 'POST',
                                      {'ref': 'main', 'inputs': {'tag': 'v2.0.5', 'repair_notes': 'false'}})])

    def test_recovery_rejects_wrong_tag_version_and_unproven_ancestry(self):
        for comparison, tag_version in (
                ({'status': 'ahead', 'merge_base_commit': {'sha': MERGE}}, b'2.0.5'),
                ({'status': 'ahead', 'merge_base_commit': {'sha': CANDIDATE}}, b'2.0.4')):
            responses = [{'object': {'type': 'commit', 'sha': CANDIDATE}}, comparison,
                         {'content': base64.b64encode(tag_version).decode()}]
            with self.subTest(comparison=comparison), patch.object(automation, 'api', side_effect=responses) as api:
                with self.assertRaisesRegex(ValueError, 'immutable tag'):
                    automation.start_release(REPO, MAIN, self.root)
            self.assertTrue(all(len(call.args) == 2 for call in api.call_args_list))

    def test_main_advancing_during_preparation_prevents_dispatch(self):
        with patch.object(automation, 'main_revision', side_effect=[MAIN, MERGE]), \
                patch.object(automation, 'api', side_effect=[
                    {'object': {'type': 'commit', 'sha': MAIN}}]) as api:
            automation.start_release(REPO, MAIN, self.root)
        self.assertEqual(api.call_count, 1)

    def test_matching_annotated_tag_can_resume_publication(self):
        with patch.object(automation, 'api', side_effect=[
                {'object': {'type': 'tag', 'sha': CANDIDATE}},
                {'object': {'type': 'commit', 'sha': MAIN}}, None]) as api:
            automation.start_release(REPO, MAIN, self.root)
        self.assertEqual(api.call_args.args[1], 'actions/workflows/release.yml/dispatches')


class MonthlyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        fixture(self.root)
        self.calls = []
        self.pull = dict(number=7, html_url='https://github.com/owner/production/pull/7',
                         state='open', draft=False, head={'sha': CANDIDATE, 'repo': {'full_name': REPO}},
                         base={'ref': 'main'})
        for name, value in (('read_marker', None), ('published_versions', ['2.0.4'])):
            mock = patch.object(automation, name, return_value=value)
            mock.start()
            self.addCleanup(mock.stop)
        mock = patch.object(automation, 'main_revision', side_effect=[MAIN, MERGE])
        mock.start()
        self.addCleanup(mock.stop)
        mock = patch.object(automation.subprocess, 'check_output', return_value=MAIN + '\n')
        mock.start()
        self.addCleanup(mock.stop)

    def api(self, repository, path, method='GET', payload=None, **kwargs):
        self.calls.append((path, method, payload))
        if path.startswith('git/ref/heads/maintenance/'):
            return None
        if path.startswith('git/commits/'):
            return {'tree': {'sha': 'tree'}}
        if path == 'git/trees':
            return {'sha': 'updated-tree'}
        if path == 'git/commits':
            return {'sha': CANDIDATE}
        if path == 'git/refs':
            return {}
        if path.startswith('pulls?'):
            return []
        if path in ('pulls', 'pulls/7'):
            return self.pull
        if path == 'pulls/7/merge':
            return {'merged': True, 'sha': MERGE}
        if path == 'actions/workflows/ci.yml/dispatches':
            return None
        raise AssertionError(path)

    def test_success_tests_before_protected_merge_and_dispatches_main_ci(self):
        def tested(*args):
            self.assertFalse(any(path.endswith('/merge') for path, _, _ in self.calls))
        with patch.object(automation, 'api', side_effect=self.api), \
                patch.object(automation, 'await_ci', side_effect=tested) as wait:
            automation.monthly_release(REPO, '2026-12', 100, self.root)
        wait.assert_called_once_with(REPO, 'maintenance/monthly-2026-12', CANDIDATE, 100)
        self.assertEqual(self.calls[-2], ('pulls/7/merge', 'PUT', {'sha': CANDIDATE, 'merge_method': 'squash'}))
        self.assertEqual(self.calls[-1], ('actions/workflows/ci.yml/dispatches', 'POST', {'ref': 'main'}))
        tree = next(payload for path, method, payload in self.calls if path == 'git/trees')
        lib = next(item for item in tree['tree'] if item['path'] == 'tests/lib.sh')
        self.assertEqual(lib['mode'], '100755')

    def test_failed_ci_and_changed_head_never_merge_or_request_main(self):
        for failed in (True, False):
            self.calls = []
            if not failed:
                self.pull['head']['sha'] = MERGE
            with self.subTest(failed=failed), patch.object(automation, 'api', side_effect=self.api), \
                    patch.object(automation, 'main_revision', return_value=MAIN), \
                    patch.object(automation, 'await_ci', side_effect=RuntimeError('CI failed') if failed else None):
                with self.assertRaises((RuntimeError, ValueError)):
                    automation.monthly_release(REPO, '2026-12', 100, self.root)
            self.assertFalse(any(path.endswith('/merge') or 'dispatches' in path for path, _, _ in self.calls))

    def test_same_month_does_not_create_another_patch(self):
        marker = dict(period='2026-12', version='2.0.5')
        with patch.object(automation, 'read_marker', return_value=marker), \
                patch.object(automation, 'published_versions', return_value=['2.0.4', '2.0.5']), \
                patch.object(automation, 'api') as api:
            automation.monthly_release(REPO, '2026-12', 100, self.root)
        api.assert_not_called()

    def test_unpublished_current_version_requests_recovery_without_a_new_patch(self):
        with patch.object(automation, 'published_versions', return_value=['2.0.3']), \
                patch.object(automation, 'api') as api:
            automation.monthly_release(REPO, '2026-12', 100, self.root)
        api.assert_called_once_with(REPO, 'actions/workflows/ci.yml/dispatches', 'POST', {'ref': 'main'})

    def test_older_main_and_missing_published_baseline_never_create_or_publish(self):
        for published in ([], ['2.0.5']):
            with self.subTest(published=published), \
                    patch.object(automation, 'published_versions', return_value=published), \
                    patch.object(automation, 'api') as api:
                with self.assertRaises(ValueError):
                    automation.monthly_release(REPO, '2026-12', 100, self.root)
            api.assert_not_called()

    def test_pending_monthly_release_resumes_main_ci_without_new_patch(self):
        with patch.object(automation, 'read_marker', return_value=dict(period='2026-12', version='2.0.5')), \
                patch.object(automation, 'dispatch_ci') as dispatch:
            automation.monthly_release(REPO, '2026-12', 100, self.root)
        dispatch.assert_called_once_with(REPO, 'main')

    def test_await_ci_rejects_failure_and_does_not_reuse_old_run(self):
        old = dict(id=1, head_sha=CANDIDATE, status='completed', conclusion='success', html_url='old')
        failed = dict(old, id=2, conclusion='failure', html_url='failed')
        with patch.object(automation, 'api', side_effect=[{'workflow_runs': [old]}, {'workflow_runs': [old, failed]}]), \
                patch.object(automation, 'dispatch_ci') as dispatch:
            with self.assertRaisesRegex(RuntimeError, 'failed'):
                automation.await_ci(REPO, 'branch', CANDIDATE, 100)
        dispatch.assert_called_once_with(REPO, 'branch')


class SourceNotesTests(unittest.TestCase):
    def test_real_git_diff_includes_added_changed_removed_and_commits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', *args], cwd=root).decode().strip()
            git('init', '-q')
            for name in ('modified', 'removed'):
                (root / name).write_text('old\n')
            git('add', '.')
            git('commit', '-qm', 'Previous release')
            git('tag', 'v2.0.4')
            (root / 'modified').write_text('new\n')
            (root / 'removed').unlink()
            (root / 'added').write_text('added\n')
            git('add', '-A')
            git('commit', '-qm', 'Add monthly refresh')
            git('tag', 'v2.0.5')
            revision = git('rev-parse', 'HEAD')
            report = notes.source_changes(root, REPO, '2.0.4', '2.0.5', revision)
            self.assertEqual({item['change']: item['path'] for item in report['files']},
                             {'A': 'added', 'M': 'modified', 'D': 'removed'})
            rendered = notes.markdown(report)
            self.assertIn('compare/v2.0.4...v2.0.5', rendered)
            self.assertIn('Add monthly refresh', rendered)
            self.assertIn('### Added files', rendered)
            with self.assertRaisesRegex(ValueError, 'does not match'):
                notes.source_changes(root, REPO, '2.0.4', '2.0.5', MAIN)


class RepositorySettingsTests(unittest.TestCase):
    def test_permission_update_must_be_confirmed_before_reporting_success(self):
        restricted = dict(default_workflow_permissions='read', can_approve_pull_request_reviews=False)
        with patch.object(settings, 'api', side_effect=[
                dict(default_branch='main', allow_squash_merge=True), restricted, None, restricted]):
            with self.assertRaisesRegex(RuntimeError, 'did not confirm'):
                settings.automation_settings('repos/' + REPO, True)

    def test_enabling_monthly_prs_keeps_default_token_permissions_restricted(self):
        restricted = dict(default_workflow_permissions='read', can_approve_pull_request_reviews=False)
        with patch.object(settings, 'api', side_effect=[
                dict(default_branch='main', allow_squash_merge=True), restricted, None,
                {**restricted, 'can_approve_pull_request_reviews': True}]) as api:
            result = settings.automation_settings('repos/' + REPO, True)
        self.assertTrue(result['can_approve_pull_request_reviews'])
        self.assertEqual(api.call_args_list[2].args,
                         ('repos/' + REPO + '/actions/permissions/workflow', 'PUT',
                          dict(default_workflow_permissions='read', can_approve_pull_request_reviews=True)))

    def test_inspection_never_writes_settings_and_existing_reviews_are_preserved(self):
        with patch.object(settings, 'api', side_effect=[
                dict(default_branch='main', allow_squash_merge=True),
                dict(default_workflow_permissions='read', can_approve_pull_request_reviews=False)]) as api:
            with self.assertRaisesRegex(ValueError, 'Allow GitHub Actions'):
                settings.automation_settings('repos/' + REPO, False)
        self.assertTrue(all(len(call.args) == 1 for call in api.call_args_list))
        protection = dict(required_pull_request_reviews=dict(required_approving_review_count=2,
                          dismiss_stale_reviews=True, require_code_owner_reviews=True),
                          enforce_admins={'enabled': True}, allow_force_pushes={'enabled': False})
        payload = settings.initial_protection(protection, {'strict': True})
        self.assertEqual(payload['required_pull_request_reviews'], protection['required_pull_request_reviews'])
        self.assertTrue(payload['enforce_admins'])
        self.assertFalse(payload['allow_force_pushes'])


if __name__ == '__main__':
    unittest.main()
