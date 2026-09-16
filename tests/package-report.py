#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
import tempfile
import json
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("package_report", Path(__file__).resolve().parents[1] / "scripts/package-report.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackageReportTests(unittest.TestCase):
    def resolve(self, reference, platform, descriptors):
        with patch.object(module, "run", return_value=json.dumps({"manifests": descriptors})) as run:
            result = module.platform_reference(reference, platform)
            run.assert_called_once_with("docker", "buildx", "imagetools", "inspect", "--raw", reference)
            return result

    def test_shared_index_resolves_distinct_platform_digests(self):
        descriptors = [
            {"digest": "sha256:amd", "platform": {"os": "linux", "architecture": "amd64"}},
            {"digest": "sha256:arm", "platform": {"os": "linux", "architecture": "arm64", "variant": "v8"}},
            {"digest": "sha256:sbom", "platform": {"os": "unknown", "architecture": "unknown"}},
            {"digest": "sha256:attestation", "platform": {"os": "linux", "architecture": "amd64"},
             "annotations": {"vnd.docker.reference.type": "attestation-manifest"}},
        ]
        reference = "joaopinto14/production@sha256:shared"
        self.assertEqual(self.resolve(reference, "linux/amd64", descriptors), "joaopinto14/production@sha256:amd")
        self.assertEqual(self.resolve(reference, "linux/arm64", descriptors), "joaopinto14/production@sha256:arm")
        self.assertEqual(self.resolve(reference, "linux/arm64/v8", descriptors), "joaopinto14/production@sha256:arm")

    def test_tag_and_registry_port(self):
        descriptors = [{"digest": "sha256:amd", "platform": {"os": "linux", "architecture": "amd64"}}]
        self.assertEqual(self.resolve("localhost:5000/team/image:2.0.3", "linux/amd64", descriptors),
                         "localhost:5000/team/image@sha256:amd")

    def test_missing_or_ambiguous_platform_fails(self):
        descriptor = {"digest": "sha256:amd", "platform": {"os": "linux", "architecture": "amd64"}}
        for descriptors in ([], [descriptor, descriptor]):
            with self.subTest(descriptors=descriptors), self.assertRaises(ValueError):
                self.resolve("image:tag", "linux/amd64", descriptors)

    def test_single_platform_reference_preserved(self):
        with patch.object(module, "run", return_value='{"schemaVersion": 2, "config": {}}'):
            self.assertEqual(module.platform_reference("image@sha256:single", "linux/amd64"), "image@sha256:single")

    def test_parse_hyphenated_package_names(self):
        self.assertEqual(module.parse_inventory("P:libcrypto3\nV:3.5.1-r0\n\nP:php85-fpm\nV:8.5.0-r1\n"),
                         {"libcrypto3": "3.5.1-r0", "php85-fpm": "8.5.0-r1"})

    def test_empty_inventory_fails(self):
        with self.assertRaises(ValueError):
            module.parse_inventory("")

    def test_added_removed_changed_and_unchanged(self):
        changes = module.changes({"a": "1", "b": "1", "c": "1"}, {"a": "2", "b": "1", "d": "1"})
        self.assertEqual([row["change"] for row in changes], ["changed", "removed", "added"])
        self.assertEqual(changes[0]["previous"], "1")
        self.assertEqual(changes[0]["current"], "2")

    def test_versioned_output_names(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "2.0.3-packages"
            module.write_report(dict(previous_version="2.0.2", version="2.0.3", scope="test", images=[]), output)
            self.assertTrue((Path(directory) / "2.0.3-packages.json").is_file())
            self.assertTrue((Path(directory) / "2.0.3-packages.md").is_file())


if __name__ == "__main__":
    unittest.main()
