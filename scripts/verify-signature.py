#!/usr/bin/env python3
"""Require a valid Cosign signature, allowing bounded registry discovery delays."""
import argparse
import re
import subprocess
import sys
import time


def verify(reference, identity, issuer, attempts=6, run=subprocess.run, sleep=time.sleep):
    if re.fullmatch(r"[a-z0-9][a-z0-9./:_-]*@sha256:[0-9a-f]{64}", reference) is None:
        raise ValueError("Expected an immutable repository@sha256:digest reference")
    if not identity or not issuer or not 1 <= attempts <= 10:
        raise ValueError("Identity/issuer are required and attempts must be from 1 to 10")
    command = ["cosign", "verify", "--certificate-identity", identity,
               "--certificate-oidc-issuer", issuer, reference]
    for attempt in range(attempts):
        result = run(command, capture_output=True, text=True, timeout=90)
        if result.returncode == 0:
            sys.stderr.write(result.stderr)
            print("Verified signature: " + reference, flush=True)
            return
        # Retry discovery absence only. Identity, certificate, claims and other
        # verification errors must still fail immediately, without any bypass.
        missing = "no signatures found" in result.stderr.lower()
        if not missing or attempt + 1 == attempts:
            raise RuntimeError(f"Cosign verification failed for {reference}: {result.stderr.strip()}")
        delay = min(5 * 2 ** attempt, 30)
        print(f"Signature not visible yet; retry {attempt + 2}/{attempts} in {delay}s: {reference}",
              file=sys.stderr, flush=True)
        sleep(delay)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference")
    parser.add_argument("--identity", required=True)
    parser.add_argument("--issuer", required=True)
    args = parser.parse_args()
    verify(args.reference, args.identity, args.issuer)


if __name__ == "__main__":
    main()
