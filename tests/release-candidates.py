#!/usr/bin/env python3
"""Candidate recovery must preserve public indexes and never rebuild them."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location(
    "release_candidates", Path(__file__).resolve().parents[1] / "scripts/release-candidates.py")
candidates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(candidates)

REPOSITORY = "example/production"
VERSION = "2.0.4"
REVISION = "a" * 40


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.output = Path(self.directory.name) / "metadata.json"
        self.targets = list(candidates.targets(VERSION))
        self.values = {target: "sha256:" + str(number) * 64
                       for number, (target, _) in enumerate(self.targets, 1)}
        self.registry = {}
        self.reads = []
        self.writes = []

    def staged(self, suffix):
        return f"{REPOSITORY}:candidate-{VERSION}-{REVISION}-{suffix}"

    def public(self, suffix):
        return f"{REPOSITORY}:{VERSION}-{suffix}"

    def inspect(self, reference):
        self.reads.append(reference)
        return self.registry.get(reference)

    def build(self, command, check):
        self.assertTrue(check)
        self.assertIn("--no-cache", command)
        target = command[3]
        suffix = dict(self.targets)[target]
        self.assertIn(f"{target}.args.VERSION={VERSION}", command)
        self.assertIn(f"{target}.args.VCS_REF={REVISION}", command)
        self.assertIn(f"{target}.tags={self.staged(suffix)}", command)
        self.writes.append(target)
        self.registry[self.staged(suffix)] = self.values[target]

    def create(self):
        with patch("builtins.print"):
            result = candidates.create_candidates(REPOSITORY, VERSION, REVISION, self.output,
                                                  inspect=self.inspect, run=self.build)
        self.assertEqual(json.loads(self.output.read_text()), result)
        self.assertEqual({target: item["containerimage.digest"] for target, item in result.items()},
                         self.values)
        return result

    def test_new_release_builds_once_and_rerun_reuses_all_staging_indexes(self):
        self.create()
        self.assertEqual(self.writes, list(self.values))
        self.writes.clear()
        self.create()
        self.assertEqual(self.writes, [])

    def test_complete_publication_recovers_without_staging_tags_or_registry_writes(self):
        for target, suffix in self.targets:
            self.registry[self.public(suffix)] = self.values[target]
        self.registry[f"{REPOSITORY}:{VERSION}"] = self.values["php85-release"]
        result = self.create()
        self.assertEqual(self.writes, [])
        self.assertTrue(all("recovered_reference" in item and "staging_reference" not in item
                            for item in result.values()))
        self.assertEqual(len(self.reads), 13)

    def test_partial_publication_combines_surviving_staging_and_public_indexes(self):
        for number, (target, suffix) in enumerate(self.targets):
            reference = self.public(suffix) if number < 3 else self.staged(suffix)
            self.registry[reference] = self.values[target]
        # PHP 8.5 can also be recovered from the shorthand version tag alone.
        del self.registry[self.public("php8.5")]
        self.registry[f"{REPOSITORY}:{VERSION}"] = self.values["php85-release"]
        self.create()
        self.assertEqual(self.writes, [])

    def test_unrecoverable_partial_publication_never_builds_or_uses_aliases(self):
        self.registry[self.public("php8.3")] = self.values["php83-release"]
        for target, suffix in self.targets:
            self.registry[f"{REPOSITORY}:{suffix}"] = self.values[target]
        self.output.write_text("stale successful metadata")
        with self.assertRaisesRegex(ValueError, "rebuilding a partly published version is forbidden"):
            self.create()
        self.assertEqual(self.writes, [])
        self.assertFalse(self.output.exists())
        self.assertNotIn(f"{REPOSITORY}:php8.5", self.reads)

    def test_public_staging_and_shorthand_conflicts_fail_before_any_build(self):
        for conflict in ("staging", "shorthand"):
            with self.subTest(conflict=conflict):
                self.registry = {self.staged(suffix): self.values[target]
                                 for target, suffix in self.targets}
                reference = self.public("php8.3") if conflict == "staging" else f"{REPOSITORY}:{VERSION}"
                self.registry[reference] = "sha256:" + "f" * 64
                self.output.write_text("stale successful metadata")
                with self.assertRaisesRegex(ValueError, "Immutable tag conflicts"):
                    self.create()
                self.assertEqual(self.writes, [])
                self.assertFalse(self.output.exists())

    def test_conflicting_public_php85_tags_fail_without_staging(self):
        self.registry[self.public("php8.5")] = self.values["php85-release"]
        self.registry[f"{REPOSITORY}:{VERSION}"] = "sha256:" + "f" * 64
        with self.assertRaisesRegex(ValueError, "Immutable tag conflicts"):
            self.create()
        self.assertEqual(self.writes, [])

    def test_registry_errors_fail_closed_before_builds(self):
        for message in ("unauthorized", "429 Too Many Requests", "connection timeout"):
            for failing_read in (1, 8):
                def inspect(reference):
                    if len(self.reads) == failing_read - 1:
                        raise RuntimeError(message)
                    return self.inspect(reference)
                self.reads.clear()
                with self.subTest(message=message, failing_read=failing_read), \
                        self.assertRaisesRegex(RuntimeError, message):
                    candidates.create_candidates(REPOSITORY, VERSION, REVISION, self.output,
                                                 inspect=inspect, run=self.build)
                self.assertEqual(self.writes, [])

    def test_partial_build_metadata_survives_failure_and_retry_builds_only_missing(self):
        def build(command, check):
            if len(self.writes) == 2:
                raise subprocess.CalledProcessError(42, command)
            self.build(command, check)
        with self.assertRaises(subprocess.CalledProcessError):
            candidates.create_candidates(REPOSITORY, VERSION, REVISION, self.output,
                                         inspect=self.inspect, run=build)
        self.assertEqual(len(json.loads(self.output.read_text())), 2)
        previous = list(self.writes)
        self.writes.clear()
        self.create()
        self.assertEqual(len(self.writes), 4)
        self.assertTrue(set(previous).isdisjoint(self.writes))

    def test_build_without_registry_candidate_fails(self):
        with self.assertRaisesRegex(ValueError, "Build did not produce"):
            candidates.create_candidates(REPOSITORY, VERSION, REVISION, self.output,
                                         inspect=self.inspect, run=Mock())


if __name__ == "__main__":
    unittest.main()
