#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
import tempfile

spec = importlib.util.spec_from_file_location("package_report", Path(__file__).resolve().parents[1] / "scripts/package-report.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackageReportTests(unittest.TestCase):
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
