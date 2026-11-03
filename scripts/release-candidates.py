#!/usr/bin/env python3
"""Build resumable staging tags once, then save the six immutable index digests."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import runpy
import subprocess

TAGS = runpy.run_path(str(Path(__file__).with_name("check-release-tags.py")))


def digest(reference):
    result = subprocess.run(["docker", "buildx", "imagetools", "inspect", reference,
                             "--raw"], capture_output=True)
    if result.returncode:
        error = result.stderr.decode().strip()
        if ("manifest unknown" in error.lower() or "no such manifest" in error.lower()
                or error.endswith(f"{reference}: not found")):
            return None
        raise RuntimeError(f"Cannot inspect {reference}: {error}")
    json.loads(result.stdout)  # Invalid/incomplete registry responses must fail.
    value = "sha256:" + hashlib.sha256(result.stdout).hexdigest()
    if re.fullmatch(r"sha256:[0-9a-f]{64}", value) is None:
        raise ValueError("Invalid registry digest")
    return value


def targets(version):
    TAGS["version_tags"](version)
    for prefix in ("", "laravel-"):
        for php in ("8.3", "8.4", "8.5"):
            yield f'{prefix}php{php.replace(".", "")}-release', f"{prefix}php{php}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="joaopinto14/production")
    parser.add_argument("--version", required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--output", type=Path, default=Path("release-metadata.json"))
    args = parser.parse_args()
    if re.fullmatch(r"[0-9a-f]{40}", args.revision) is None:
        raise ValueError("Expected a complete Git commit SHA")
    plan = [(target, suffix, f"{args.repository}:candidate-{args.version}-{args.revision}-{suffix}")
            for target, suffix in targets(args.version)]
    found = {target: digest(reference) for target, _, reference in plan}
    # Missing staging tags after a partial public promotion must be recovered
    # from saved metadata, never silently rebuilt with mutable APK repositories.
    if not all(found.values()):
        TAGS["check_tags"](args.repository, args.version)
    metadata = {}
    for target, suffix, reference in plan:
        if found[target] is None:
            subprocess.run(["docker", "buildx", "bake", target, "--push", "--pull", "--no-cache",
                            "--set", f"{target}.tags={reference}", "--set", f"{target}.args.VERSION={args.version}",
                            "--set", f"{target}.args.VCS_REF={args.revision}"], check=True)
            found[target] = digest(reference)
            if found[target] is None:
                raise ValueError("Build did not produce a registry candidate")
        metadata[target] = {"containerimage.digest": found[target], "staging_reference": reference}
        args.output.write_text(json.dumps(metadata, indent=2) + "\n")


if __name__ == "__main__":
    main()
