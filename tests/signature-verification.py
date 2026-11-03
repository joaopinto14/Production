#!/usr/bin/env python3
"""Discovery retries must never turn failed signature verification into success."""
from pathlib import Path
import runpy
from subprocess import CompletedProcess
import unittest
from unittest.mock import Mock

VERIFY = runpy.run_path(str(Path(__file__).resolve().parents[1] / "scripts/verify-signature.py"))["verify"]
REFERENCE = "example/production@sha256:" + "a" * 64
IDENTITY = "https://github.com/example/production/.github/workflows/release.yml@refs/tags/v2.0.4"
ISSUER = "https://token.actions.githubusercontent.com"


def result(code, error=""):
    return CompletedProcess([], code, stdout="", stderr=error)


class SignatureTests(unittest.TestCase):
    def test_delayed_discovery_keeps_the_exact_identity_issuer_and_digest(self):
        run = Mock(side_effect=[result(10, "Error: no signatures found"),
                               result(10, "Error: no signatures found"), result(0)])
        sleep = Mock()
        VERIFY(REFERENCE, IDENTITY, ISSUER, run=run, sleep=sleep)
        self.assertEqual([call.args[0] for call in sleep.call_args_list], [5, 10])
        expected = ["cosign", "verify", "--certificate-identity", IDENTITY,
                    "--certificate-oidc-issuer", ISSUER, REFERENCE]
        self.assertTrue(all(call.args[0] == expected for call in run.call_args_list))

    def test_missing_signature_exhausts_the_bound_and_fails(self):
        run = Mock(return_value=result(10, "Error: no signatures found"))
        sleep = Mock()
        with self.assertRaisesRegex(RuntimeError, "no signatures found"):
            VERIFY(REFERENCE, IDENTITY, ISSUER, run=run, sleep=sleep)
        self.assertEqual(run.call_count, 6)
        self.assertEqual([call.args[0] for call in sleep.call_args_list], [5, 10, 20, 30, 30])

    def test_identity_certificate_claims_and_network_errors_are_not_bypassed(self):
        for error in ("certificate identity mismatch", "invalid signature", "claims mismatch", "registry unavailable"):
            run, sleep = Mock(return_value=result(1, error)), Mock()
            with self.subTest(error=error), self.assertRaises(RuntimeError):
                VERIFY(REFERENCE, IDENTITY, ISSUER, run=run, sleep=sleep)
            self.assertEqual(run.call_count, 1)
            sleep.assert_not_called()

    def test_success_needs_no_wait_and_mutable_references_are_rejected(self):
        run, sleep = Mock(return_value=result(0)), Mock()
        VERIFY(REFERENCE, IDENTITY, ISSUER, run=run, sleep=sleep)
        sleep.assert_not_called()
        with self.assertRaises(ValueError):
            VERIFY("example/production:latest", IDENTITY, ISSUER, run=run, sleep=sleep)
        self.assertEqual(run.call_count, 1)


if __name__ == "__main__":
    unittest.main()
