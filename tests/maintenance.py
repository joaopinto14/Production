#!/usr/bin/env python3
import copy
from datetime import datetime, timedelta, timezone
import os
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).resolve().parents[1] / "scripts" / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


candidates = load("candidates", "check-candidates.py")
release = load("release_tags", "check-release-tags.py")


class BaseTests(unittest.TestCase):
    def test_pinned_index_reference(self):
        for tag in ("3.24", "3.24.2"):
            reference = f"alpine:{tag}@sha256:" + "a" * 64
            self.assertEqual(candidates.base_reference(f"FROM {reference}\n"), reference)

    def test_mutable_or_indirect_base_is_rejected(self):
        for dockerfile in ("FROM alpine:3.24", "FROM ${ALPINE_IMAGE}", "FROM alpine:latest@sha256:" + "a" * 64):
            with self.subTest(dockerfile=dockerfile), self.assertRaises(ValueError):
                candidates.base_reference(dockerfile)

    def test_single_platform_and_attestation_cannot_replace_arm64(self):
        manifest = {"manifests": [
            {"platform": {"os": "linux", "architecture": "amd64"}},
            {"platform": {"os": "linux", "architecture": "arm64"},
             "annotations": {"vnd.docker.reference.type": "attestation-manifest"}},
        ]}
        with self.assertRaises(ValueError):
            candidates.check_platforms(manifest)
        manifest["manifests"][1].pop("annotations")
        candidates.check_platforms(manifest)
        with self.assertRaises(ValueError):
            candidates.check_platforms({"config": {}})

    def test_candidate_must_contain_exact_base_layers(self):
        candidates.check_base_layers(["base"], ["base", "runtime"])
        for base, image in (([], ["runtime"]), (["new-base"], ["old-base", "runtime"]), (["a", "b"], ["a"])):
            with self.subTest(base=base, image=image), self.assertRaises(ValueError):
                candidates.check_base_layers(base, image)

    def test_archive_identity_uses_config_digest_in_both_docker_store_formats(self):
        image_info = {"Os": "linux", "Architecture": "amd64", "RootFS": {"Layers": ["layer"]}}
        data = json.dumps({"os": "linux", "architecture": "amd64", "rootfs": {"diff_ids": ["layer"]}}).encode()
        expected = "sha256:" + hashlib.sha256(data).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "image.tar"
            for name in ("config.json", "blobs/sha256/config"):
                with tarfile.open(path, "w") as archive:
                    for filename, content in ((name, data), ("manifest.json", json.dumps([{"Config": name}]).encode())):
                        member = tarfile.TarInfo(filename)
                        member.size = len(content)
                        archive.addfile(member, io.BytesIO(content))
                self.assertEqual(candidates.archive_config_digest(path, image_info), expected)
                with self.assertRaises(ValueError):
                    candidates.archive_config_digest(path, {**image_info, "Architecture": "arm64"})
                with self.assertRaises(ValueError):
                    candidates.archive_config_digest(path, {**image_info, "RootFS": {"Layers": ["other"]}})


class ScanTests(unittest.TestCase):
    def setUp(self):
        self.report = {
            "SchemaVersion": 2, "ArtifactType": "container_image",
            "Trivy": {"Version": "0.76.1"}, "CreatedAt": datetime.now(timezone.utc).isoformat(),
            "Metadata": {"ImageID": "sha256:candidate", "OS": {"Family": "alpine", "EOSL": False}},
            "Results": [{"Class": "os-pkgs", "Packages": [{"Name": "musl", "Version": "1"}],
                         "Vulnerabilities": []}],
        }

    def test_fixable_high_and_critical_block_but_other_findings_remain_visible(self):
        findings = [
            {"Severity": "HIGH", "FixedVersion": "2", "VulnerabilityID": "high-fixed"},
            {"Severity": "CRITICAL", "FixedVersion": "2", "VulnerabilityID": "critical-fixed"},
            {"Severity": "HIGH", "FixedVersion": "", "VulnerabilityID": "high-unfixed"},
            {"Severity": "LOW", "FixedVersion": "2", "VulnerabilityID": "low-fixed"},
        ]
        self.report["Results"][0]["Vulnerabilities"] = findings
        self.assertEqual(candidates.blocking_vulnerabilities(self.report, "sha256:candidate", {"musl": "1"}), findings[:2])
        self.assertEqual(len(self.report["Results"][0]["Vulnerabilities"]), 4)

    def test_clean_scan_requires_packages_and_image_identity(self):
        self.assertEqual(candidates.blocking_vulnerabilities(self.report, "sha256:candidate", {"musl": "1"}), [])
        with self.assertRaises(ValueError):
            candidates.blocking_vulnerabilities(self.report, "sha256:another-image", {"musl": "1"})

    def test_empty_incomplete_wrong_os_and_eol_reports_fail_closed(self):
        mutations = [({}, self.report), ({"SchemaVersion": 1}, self.report),
                     ({"ArtifactType": "filesystem"}, self.report), ({"Results": []}, self.report)]
        for override, original in mutations:
            report = {} if not override else {**original, **override}
            with self.subTest(report=report), self.assertRaises(ValueError):
                candidates.blocking_vulnerabilities(report, "sha256:candidate", {"musl": "1"})
        for os_info in ({}, {"Family": "debian"}, {"Family": "alpine", "EOSL": True}):
            report = copy.deepcopy(self.report)
            report["Metadata"]["OS"] = os_info
            with self.subTest(os_info=os_info), self.assertRaises(ValueError):
                candidates.blocking_vulnerabilities(report, "sha256:candidate", {"musl": "1"})
        self.report["Results"][0]["Packages"] = []
        with self.assertRaises(ValueError):
            candidates.blocking_vulnerabilities(self.report, "sha256:candidate", {"musl": "1"})


class ReleaseTagTests(unittest.TestCase):
    def test_all_seven_version_tags_are_checked_without_aliases(self):
        tags = release.version_tags("2.0.4")
        self.assertEqual(len(set(tags)), 7)
        self.assertIn("2.0.4", tags)
        self.assertIn("2.0.4-laravel-php8.5", tags)
        self.assertNotIn("latest", tags)

    def test_invalid_versions_are_rejected(self):
        for version in ("2.0.4-rc.1", "v2.0.4", "02.0.4", "2.0.4\n"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                release.version_tags(version)

    def test_existing_tag_prevents_publication(self):
        with patch.object(release.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "manifest", "")) as run:
            with self.assertRaisesRegex(ValueError, "already exists"):
                release.check_tags("example/production", "2.0.4")
            self.assertEqual(run.call_count, 1)

    def test_only_explicit_missing_manifests_allow_publication(self):
        for error in ("manifest unknown", "no such manifest"):
            with self.subTest(error=error), patch.object(release.subprocess, "run", return_value=
                    subprocess.CompletedProcess([], 1, "", error)) as run, patch("builtins.print"):
                release.check_tags("example/production", "2.0.4")
                self.assertEqual(run.call_count, 7)

    def test_buildx_not_found_format(self):
        def missing(args, **kwargs):
            return subprocess.CompletedProcess(args, 1, "", f"ERROR: {args[-1]}: not found\n")
        with patch.object(release.subprocess, "run", side_effect=missing), patch("builtins.print"):
            release.check_tags("example/production", "2.0.4")

    def test_network_authentication_rate_limit_and_command_errors_fail_closed(self):
        for error in ("unauthorized", "429 Too Many Requests", "registry host not found", "connection timeout"):
            with self.subTest(error=error), patch.object(release.subprocess, "run", return_value=
                    subprocess.CompletedProcess([], 1, "", error)):
                with self.assertRaises(RuntimeError):
                    release.check_tags("example/production", "2.0.4")


class IntegrityRegressionTests(unittest.TestCase):
    def test_partial_inventories_and_wrong_versions_cannot_pass(self):
        fixture = ScanTests()
        fixture.setUp()
        for expected in ({"musl": "1", "php85": "8.5.11-r0"}, {"musl": "2"}, {}):
            with self.subTest(expected=expected), self.assertRaises(ValueError):
                candidates.blocking_vulnerabilities(fixture.report, "sha256:candidate", expected)
        fixture.report["Results"][0]["Packages"] *= 2
        with self.assertRaises(ValueError):
            candidates.blocking_vulnerabilities(fixture.report, "sha256:candidate", {"musl": "1"})

    def test_stale_and_future_databases_and_reports_fail(self):
        now = datetime.now(timezone.utc)
        good = dict(Version=2, UpdatedAt=now.isoformat(), DownloadedAt=now.isoformat())
        candidates.check_database(good, now)
        for field in ("UpdatedAt", "DownloadedAt"):
            for hours in (-49, 1):
                bad = {**good, field: (now + timedelta(hours=hours)).isoformat()}
                with self.assertRaises(ValueError):
                    candidates.check_database(bad, now)
        fixture = ScanTests()
        fixture.setUp()
        fixture.report["CreatedAt"] = (now - timedelta(days=2)).isoformat()
        with self.assertRaises(ValueError):
            candidates.blocking_vulnerabilities(fixture.report, "sha256:candidate", {"musl": "1"})

    def test_both_size_suites_fail_on_save_and_compressor_errors(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for failing in ("docker", "gzip"):
                (root / "docker").write_text("#!/bin/sh\ncase \"$*\" in *save*) exit " +
                                            ("42" if failing == "docker" else "0") + ";; *) exit 0;; esac\n")
                (root / "gzip").write_text("#!/bin/sh\nexit 43\n")
                for path in root.iterdir():
                    path.chmod(0o755)
                for script in ("tests/size-budget.sh", "tests/compare-size.sh"):
                    with self.subTest(failing=failing, script=script):
                        result = subprocess.run(["sh", script], env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}"},
                                                capture_output=True, text=True)
                        self.assertNotEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
