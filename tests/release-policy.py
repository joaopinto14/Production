#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("release_policy", Path(__file__).resolve().parents[1] / "scripts/release-policy.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleasePolicyTests(unittest.TestCase):
    def test_current_release(self):
        self.assertEqual(module.policy("2.0.3", ["v2.0.2", "v2.0.3"]), (True, "2.0.2"))

    def test_old_release_cannot_promote(self):
        self.assertEqual(module.policy("2.0.2", ["v2.0.1", "v2.0.3"]), (False, "2.0.1"))

    def test_numeric_order_and_prereleases(self):
        self.assertEqual(module.policy("2.0.9", ["v2.0.10", "v3.0.0-rc.1", "v2.0.8"]), (False, "2.0.8"))

    def test_no_baseline_is_explicit(self):
        self.assertEqual(module.policy("2.0.0", []), (True, ""))

    def test_invalid_version(self):
        with self.assertRaises(ValueError):
            module.policy("2.0.3-rc.1", [])


if __name__ == "__main__":
    unittest.main()
