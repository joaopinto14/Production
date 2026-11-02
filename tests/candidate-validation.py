#!/usr/bin/env python3
"""Ensure release test failures cannot be hidden by logging or stale results."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("validation", Path(__file__).resolve().parents[1] / "scripts/validate-candidate.py")
validation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validation)


class ValidationTests(unittest.TestCase):
    def test_log_capture_preserves_nonzero_exit(self):
        popen = subprocess.Popen
        def command(*args, **kwargs):
            return popen([sys.executable, "-c", "print('fixture output'); raise SystemExit(23)"], **kwargs)
        with tempfile.TemporaryDirectory() as directory, patch.object(validation.subprocess, "Popen", side_effect=command):
            result = validation.run_suite("fixture", Path(directory), dict(os.environ))
            self.assertEqual(result["exit_code"], 23)
            self.assertEqual((Path(directory) / "fixture.log").read_text(), "fixture output\n")

    def test_failure_replaces_old_success_and_stops_following_suites(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "runtime-tests.json"
            path.write_text('{"status":"passed"}')
            argv = ["validate-candidate", "--platform", "linux/amd64", "--output", directory]
            with patch.object(sys, "argv", argv), patch.object(validation, "snapshot", return_value={"php8.5": "image"}), \
                    patch.object(validation, "run_suite", return_value=dict(name="test-all", exit_code=7, log="test-all.log")) as run:
                with self.assertRaises(RuntimeError):
                    validation.main()
            self.assertEqual(run.call_count, 1)
            result = json.loads(path.read_text())
            self.assertEqual(result["status"], "failed")
            self.assertIn("completed_at", result)

    def test_image_replacement_during_tests_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            argv = ["validate-candidate", "--platform", "linux/amd64", "--output", directory]
            with patch.object(sys, "argv", argv), \
                    patch.object(validation, "snapshot", side_effect=[{"php8.5": "old"}, {"php8.5": "new"}]), \
                    patch.object(validation, "run_suite", return_value=dict(name="test-all", exit_code=0)):
                with self.assertRaisesRegex(RuntimeError, "IDs changed"):
                    validation.main()
            self.assertEqual(json.loads((Path(directory) / "runtime-tests.json").read_text())["status"], "failed")


if __name__ == "__main__":
    unittest.main()
