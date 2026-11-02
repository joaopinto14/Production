#!/usr/bin/env python3
"""Publication state-machine regressions; no registry or credentials required."""
import copy
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("promotion", Path(__file__).resolve().parents[1] / "scripts/promote-release.py")
promotion = importlib.util.module_from_spec(spec)
spec.loader.exec_module(promotion)


class PromotionTests(unittest.TestCase):
    def setUp(self):
        self.metadata = {target: {"containerimage.digest": "sha256:" + str(i) * 64}
                         for i, (target, _) in enumerate(promotion.CANDIDATES["targets"]("2.0.4"), 1)}
        self.plan = promotion.plan("example/production", "2.0.4", self.metadata, True)

    def test_complete_version_tags_precede_all_aliases(self):
        self.assertEqual(len(self.plan), 15)
        self.assertTrue(all(item["immutable"] for item in self.plan[:7]))
        self.assertFalse(any(item["immutable"] for item in self.plan[7:]))
        historical = promotion.plan("example/production", "2.0.4", self.metadata, False)
        self.assertEqual(len(historical), 7)

    def test_conflict_preflight_prevents_any_write(self):
        writes = []
        with tempfile.TemporaryDirectory() as directory, self.assertRaisesRegex(ValueError, "conflicts"):
            promotion.promote(self.plan, Path(directory) / "journal.json",
                              inspect=lambda reference: "different-digest" if reference == self.plan[6]["reference"] else None,
                              run=lambda *args, **kwargs: writes.append(args))
        self.assertEqual(writes, [])

    def test_partial_publication_resumes_without_rewriting_identical_tags(self):
        state, writes = {}, []

        def run(command, check):
            reference = command[command.index("--tag") + 1]
            if len(writes) == 3:
                raise subprocess.CalledProcessError(42, command)
            writes.append(reference)
            state[reference] = command[-1].split("@", 1)[1]

        with tempfile.TemporaryDirectory() as directory:
            journal = Path(directory) / "journal.json"
            with self.assertRaises(subprocess.CalledProcessError):
                promotion.promote(self.plan, journal, inspect=state.get, run=run)
            self.assertEqual(len(json.loads(journal.read_text())["completed"]), 3)
            self.assertFalse(any(not item["immutable"] for item in self.plan if item["reference"] in state))
            previous = list(writes)

            def resume(command, check):
                reference = command[command.index("--tag") + 1]
                self.assertNotIn(reference, previous)
                writes.append(reference)
                state[reference] = command[-1].split("@", 1)[1]

            promotion.promote(self.plan, journal, inspect=state.get, run=resume)
            self.assertEqual(len(writes), 15)
            self.assertEqual(len(json.loads(journal.read_text())["completed"]), 15)

    def test_registry_errors_never_mean_missing_tag(self):
        with tempfile.TemporaryDirectory() as directory, self.assertRaises(RuntimeError):
            def unavailable(reference):
                raise RuntimeError("registry unavailable")
            promotion.promote(self.plan, Path(directory) / "journal.json", inspect=unavailable)

    def evidence(self, root):
        now = datetime.now(timezone.utc).isoformat()
        for arch in ("amd64", "arm64"):
            directory = root / arch
            directory.mkdir()
            images = []
            for target, suffix in promotion.CANDIDATES["targets"]("2.0.4"):
                images.append(dict(variant="laravel" if suffix.startswith("laravel-") else "generic",
                                   php=suffix[-3:], reference="example/production@" + self.metadata[target]["containerimage.digest"],
                                   revision="a" * 40, config_digest="sha256:config", packages={"musl": "1"},
                                   image_id="sha256:" + target,
                                   database=dict(Version=2, UpdatedAt=now, DownloadedAt=now)))
                (directory / f"trivy-{suffix}.json").write_text(json.dumps(dict(
                    SchemaVersion=2, ArtifactType="container_image", Trivy={"Version": "0.76.1"}, CreatedAt=now,
                    Metadata=dict(ImageID="sha256:config", OS=dict(Family="alpine", EOSL=False)),
                    Results=[dict(Class="os-pkgs", Packages=[dict(Name="musl", Version="1")])]
                )))
            (directory / "inventory.json").write_text(json.dumps(dict(version="2.0.4", platform=f"linux/{arch}", images=images)))
            suites = []
            for name in promotion.VALIDATION["SUITES"]:
                log = directory / f"{name}.log"
                log.write_text("passed\n")
                suites.append(dict(name=name, exit_code=0, log=log.name,
                                   sha256=hashlib.sha256(log.read_bytes()).hexdigest()))
            (directory / "runtime-tests.json").write_text(json.dumps(dict(
                version="2.0.4", revision="a" * 40, platform=f"linux/{arch}", status="passed",
                started_at=now, completed_at=now, suites=suites,
                images={f'{"laravel-" if x["variant"] == "laravel" else ""}php{x["php"]}': x["image_id"] for x in images})))

    def test_both_platforms_and_all_six_exact_artifacts_are_required(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.evidence(root)
            promotion.validate_evidence(root, "2.0.4", "example/production", self.metadata, "a" * 40)
            path = root / "arm64/inventory.json"
            original = json.loads(path.read_text())
            for mutation in ("missing", "wrong-digest", "wrong-revision", "duplicate"):
                value = copy.deepcopy(original)
                if mutation == "missing":
                    value["images"].pop()
                elif mutation == "duplicate":
                    value["images"].append(value["images"][0])
                else:
                    value["images"][0]["reference" if mutation == "wrong-digest" else "revision"] = "wrong"
                path.write_text(json.dumps(value))
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    promotion.validate_evidence(root, "2.0.4", "example/production", self.metadata, "a" * 40)

    def test_runtime_failures_stale_results_changed_images_and_logs_block_promotion(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.evidence(root)
            path = root / "arm64/runtime-tests.json"
            original = json.loads(path.read_text())
            for mutation in ("failed", "missing-suite", "suite-failure", "wrong-image", "stale", "wrong-revision", "changed-log"):
                value = copy.deepcopy(original)
                if mutation == "failed":
                    value["status"] = "failed"
                elif mutation == "missing-suite":
                    value["suites"].pop()
                elif mutation == "suite-failure":
                    value["suites"][0]["exit_code"] = 1
                elif mutation == "wrong-image":
                    value["images"]["php8.5"] = "other"
                elif mutation == "stale":
                    value["completed_at"] = "2020-01-01T00:00:00+00:00"
                elif mutation == "wrong-revision":
                    value["revision"] = "b" * 40
                else:
                    value["suites"][0]["sha256"] = "bad"
                path.write_text(json.dumps(value))
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    promotion.validate_evidence(root, "2.0.4", "example/production", self.metadata, "a" * 40)
            path.unlink()
            with self.assertRaises(FileNotFoundError):
                promotion.validate_evidence(root, "2.0.4", "example/production", self.metadata, "a" * 40)


if __name__ == "__main__":
    unittest.main()
