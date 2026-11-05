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


def create_candidates(repository, version, revision, output, inspect=None, run=None):
    inspect = inspect or digest
    run = run or subprocess.run
    if re.fullmatch(r"[0-9a-f]{40}", revision) is None:
        raise ValueError("Expected a complete Git commit SHA")
    plan = [(target, suffix, f"{repository}:candidate-{version}-{revision}-{suffix}")
            for target, suffix in targets(version)]
    output.unlink(missing_ok=True)
    metadata = {}
    for target, _, reference in plan:
        value = inspect(reference)
        if value is not None:
            metadata[target] = {"containerimage.digest": value, "staging_reference": reference}

    # Preflight all seven immutable version tags, including the PHP 8.5 shorthand.
    # A lost staging tag can be recovered from the original public index without
    # rebuilding or changing registry state. Moving aliases are never candidates.
    published = False
    for target, suffix, _ in plan:
        tags = [f"{version}-{suffix}"] + ([version] if suffix == "php8.5" else [])
        for tag in tags:
            reference = f"{repository}:{tag}"
            value = inspect(reference)
            if value is None:
                continue
            published = True
            if target in metadata and metadata[target]["containerimage.digest"] != value:
                raise ValueError(f"Immutable tag conflicts with candidate digest: {reference}")
            if target not in metadata:
                metadata[target] = {"containerimage.digest": value, "recovered_reference": reference}
                print(f"Recovered candidate from {reference}@{value}")

    missing = [target for target, _, _ in plan if target not in metadata]
    if published and missing:
        raise ValueError("Version tags already exist but candidate digests are missing for: "
                         + ", ".join(missing) + ". Restore the original saved candidate digests "
                         "or publish a new version; rebuilding a partly published version is forbidden.")
    if metadata:
        output.write_text(json.dumps(metadata, indent=2) + "\n")
    for target, _, reference in plan:
        if target not in metadata:
            run(["docker", "buildx", "bake", target, "--push", "--pull", "--no-cache",
                 "--set", f"{target}.tags={reference}", "--set", f"{target}.args.VERSION={version}",
                 "--set", f"{target}.args.VCS_REF={revision}"], check=True)
            value = inspect(reference)
            if value is None:
                raise ValueError("Build did not produce a registry candidate")
            metadata[target] = {"containerimage.digest": value, "staging_reference": reference}
            output.write_text(json.dumps(metadata, indent=2) + "\n")
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="joaopinto14/production")
    parser.add_argument("--version", required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--output", type=Path, default=Path("release-metadata.json"))
    args = parser.parse_args()
    create_candidates(args.repository, args.version, args.revision, args.output)


if __name__ == "__main__":
    main()
