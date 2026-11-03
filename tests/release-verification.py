#!/usr/bin/env python3
"""Registry verification regressions without a live registry."""
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import runpy
import unittest
from unittest.mock import Mock

VERIFY = runpy.run_path(str(Path(__file__).resolve().parents[1] / "scripts/verify-release.py"))


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.metadata, self.registry = {}, {}
        for number, (target, suffix) in enumerate(VERIFY["CANDIDATES"]["targets"]("2.0.4"), 1):
            digest = "sha256:" + str(number) * 64
            self.metadata[target] = {"containerimage.digest": digest}
            images, sboms, provenance, manifests = {}, {}, {}, []
            for arch in ("amd64", "arm64"):
                platform = f"linux/{arch}"
                manifests.append(dict(digest="sha256:" + ("a" if arch == "amd64" else "b") * 64,
                                      platform=dict(os="linux", architecture=arch)))
                images[platform] = dict(os="linux", architecture=arch, config=dict(User="www", Labels={
                    "org.opencontainers.image.version": "2.0.4", "org.opencontainers.image.revision": "a" * 40,
                    "io.joaopinto.production.variant": "laravel" if suffix.startswith("laravel-") else "generic",
                    "io.joaopinto.production.php-version": suffix[-3:]}))
                sboms[platform] = dict(SPDX=dict(spdxVersion="SPDX-2.3", documentNamespace="urn:test", packages=[dict(name="musl")]))
                provenance[platform] = dict(SLSA=dict(buildType="https://mobyproject.org/buildkit@v1"))
            data = dict(Manifest=dict(digest=digest, manifests=manifests), Image=images, SBOM=sboms, Provenance=provenance)
            self.registry[f"example/production@{digest}"] = data
            tags = [f"2.0.4-{suffix}", suffix]
            if suffix == "php8.5":
                tags += ["2.0.4", "latest"]
            if suffix == "laravel-php8.5":
                tags.append("laravel")
            for tag in tags:
                self.registry[f"example/production:{tag}"] = data

    def verify(self, **kwargs):
        return VERIFY["verify"]("example/production", "2.0.4", "a" * 40, self.metadata,
                                read=lambda ref, field: self.registry[ref][field], **kwargs)

    def test_complete_registry_and_all_fifteen_tags(self):
        result = self.verify(published=True, aliases=True)
        self.assertEqual(len(result["images"]), 6)
        self.assertEqual(sum(len(item["tags"]) for item in result["images"]), 15)
        self.assertEqual(sum(len(item["tags"]) for item in self.verify(published=True)["images"]), 7)

    def test_missing_duplicate_or_wrong_platform_is_rejected(self):
        data = self.registry[next(iter(self.registry))]
        original = copy.deepcopy(data["Manifest"])
        for mutation in ("missing", "duplicate", "wrong", "digest"):
            value = copy.deepcopy(original)
            if mutation == "missing":
                value["manifests"].pop()
            elif mutation == "duplicate":
                value["manifests"].append(value["manifests"][0])
            elif mutation == "wrong":
                value["manifests"][0]["platform"]["architecture"] = "386"
            else:
                value["digest"] = "sha256:" + "0" * 64
            data["Manifest"] = value
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.verify()

    def test_missing_sbom_provenance_and_wrong_identity_are_rejected(self):
        key = next(iter(self.registry))
        original = copy.deepcopy(self.registry[key])
        for mutation in ("sbom", "empty-sbom", "provenance", "revision", "root"):
            value = copy.deepcopy(original)
            if mutation == "sbom":
                value["SBOM"].pop("linux/arm64")
            elif mutation == "empty-sbom":
                value["SBOM"]["linux/arm64"]["SPDX"]["packages"] = []
            elif mutation == "provenance":
                value["Provenance"]["linux/arm64"] = None
            elif mutation == "root":
                value["Image"]["linux/arm64"]["config"]["User"] = "root"
            else:
                value["Image"]["linux/arm64"]["config"]["Labels"]["org.opencontainers.image.revision"] = "wrong"
            self.registry[key] = value
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.verify()

    def test_tag_drift_is_rejected(self):
        self.registry["example/production:latest"] = dict(Manifest=dict(digest="wrong"))
        self.verify(published=True)  # Historical releases do not verify moving aliases.
        with self.assertRaisesRegex(ValueError, "latest"):
            self.verify(published=True, aliases=True)

    def test_incomplete_metadata_and_registry_errors_fail(self):
        original = copy.deepcopy(self.metadata)
        self.metadata.pop(next(iter(self.metadata)))
        with self.assertRaises(ValueError):
            self.verify()
        self.metadata = original
        self.registry.clear()
        with self.assertRaises(KeyError):
            self.verify()

    def test_reusing_verified_indexes_still_reads_all_final_tags_and_rejects_drift(self):
        artifacts = self.verify()
        reads = []
        def read(reference, field):
            self.assertNotIn("@", reference)
            self.assertEqual(field, "Manifest")
            reads.append(reference)
            return self.registry[reference][field]
        VERIFY["verify"]("example/production", "2.0.4", "a" * 40, self.metadata,
                         published=True, aliases=True, read=read, artifacts=artifacts)
        self.assertEqual(len(reads), 15)
        self.registry["example/production:latest"] = dict(Manifest=dict(digest="wrong"))
        with self.assertRaisesRegex(ValueError, "latest"):
            VERIFY["verify"]("example/production", "2.0.4", "a" * 40, self.metadata,
                             published=True, aliases=True, read=read, artifacts=artifacts)

    def test_stale_mismatched_incomplete_or_changed_prior_artifacts_are_rejected(self):
        original = self.verify()
        for mutation in ("stale", "revision", "digest", "missing", "duplicate", "empty-sbom"):
            value = copy.deepcopy(original)
            if mutation == "stale":
                value["created_at"] = (datetime.now(timezone.utc) - timedelta(days=2)).isoformat()
            elif mutation == "revision":
                value["revision"] = "wrong"
            elif mutation == "digest":
                value["images"][0]["reference"] = "wrong"
            elif mutation == "missing":
                value["images"].pop()
            elif mutation == "duplicate":
                value["images"].append(value["images"][0])
            else:
                value["images"][0]["sbom"]["linux/arm64"]["SPDX"]["packages"] = []
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.verify(published=True, artifacts=value)


class ReaderTests(unittest.TestCase):
    def test_raw_index_digest_and_single_combined_content_read(self):
        raw = b'{"schemaVersion":2,"manifests":[]}\n'
        contents = {"Image": {"config": "test"}, "SBOM": {"SPDX": "test"}, "Provenance": {"SLSA": "test"}}
        run = Mock(side_effect=[raw, json.dumps(contents).encode()])
        read = VERIFY["RegistryReader"](run=run)
        reference = "example/production@sha256:" + "a" * 64
        self.assertEqual(read(reference, "Manifest")["digest"], "sha256:" + hashlib.sha256(raw).hexdigest())
        for field in contents:
            self.assertEqual(read(reference, field), contents[field])
        self.assertEqual(run.call_count, 2)
        self.assertEqual(run.call_args_list[0].args[0][-1], "--raw")
        self.assertIn(".Image", run.call_args_list[1].args[0][-1])
        self.assertIn(".SBOM", run.call_args_list[1].args[0][-1])
        self.assertIn(".Provenance", run.call_args_list[1].args[0][-1])


if __name__ == "__main__":
    unittest.main()
