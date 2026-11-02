#!/usr/bin/env python3
"""Promote validated index digests without rebuilding; resume identical tags only."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import runpy
import subprocess

CANDIDATES = runpy.run_path(str(Path(__file__).with_name("release-candidates.py")))
SCANNER = runpy.run_path(str(Path(__file__).with_name("check-candidates.py")))
VALIDATION = runpy.run_path(str(Path(__file__).with_name("validate-candidate.py")))


def validate_runtime(directory, version, platform, revision, images):
    result = json.loads((directory / "runtime-tests.json").read_text())
    if (result.get("status") != "passed" or result.get("version") != version
            or result.get("platform") != platform or result.get("revision") != revision):
        raise ValueError("Missing or mismatched successful runtime validation")
    for field in ("started_at", "completed_at"):
        stamp = datetime.fromisoformat(result[field].replace("Z", "+00:00"))
        if not -300 <= (datetime.now(timezone.utc) - stamp).total_seconds() <= 24 * 3600:
            raise ValueError("Stale or future runtime validation")
    expected = {f'{"laravel-" if item["variant"] == "laravel" else ""}php{item["php"]}': item["image_id"]
                for item in images}
    if result.get("images") != expected:
        raise ValueError("Runtime validation does not identify the scanned images")
    suites = result.get("suites", [])
    if [item.get("name") for item in suites] != list(VALIDATION["SUITES"]):
        raise ValueError("Incomplete runtime validation suites")
    for item in suites:
        if item.get("exit_code") != 0 or item.get("log") != f'{item["name"]}.log':
            raise ValueError("Failed runtime validation suite")
        digest = hashlib.sha256((directory / item["log"]).read_bytes()).hexdigest()
        if item.get("sha256") != digest:
            raise ValueError("Runtime validation log is missing or changed")


def plan(repository, version, metadata, aliases):
    result = []
    for target, suffix in CANDIDATES["targets"](version):
        value = metadata[target]["containerimage.digest"]
        tags = [f"{version}-{suffix}"]
        if suffix == "php8.5":
            tags.append(version)
        if aliases:
            tags.append(suffix)
            if suffix in ("php8.5", "laravel-php8.5"):
                tags.append("latest" if suffix == "php8.5" else "laravel")
        for tag in tags:
            result.append(dict(reference=f"{repository}:{tag}", digest=value,
                               immutable=tag.startswith(version)))
    # Complete all versioned tags before moving any convenience alias.
    return sorted(result, key=lambda item: not item["immutable"])


def validate_evidence(root, version, repository, metadata, revision):
    for arch in ("amd64", "arm64"):
        directory = root / arch
        evidence = json.loads((directory / "inventory.json").read_text())
        if evidence["version"] != version or evidence["platform"] != f"linux/{arch}":
            raise ValueError("Wrong release/platform in scan evidence")
        images = evidence["images"]
        expected = {suffix for _, suffix in CANDIDATES["targets"](version)}
        seen = set()
        for item in images:
            suffix = f'{"laravel-" if item["variant"] == "laravel" else ""}php{item["php"]}'
            target = f'{"laravel-" if item["variant"] == "laravel" else ""}php{item["php"].replace(".", "")}-release'
            if suffix in seen or suffix not in expected:
                raise ValueError("Duplicate/unexpected candidate evidence")
            seen.add(suffix)
            if item["reference"] != f'{repository}@{metadata[target]["containerimage.digest"]}':
                raise ValueError("Scan evidence does not match candidate index digest")
            if item.get("revision") != revision:
                raise ValueError("Wrong source revision in candidate evidence")
            SCANNER["check_database"](item["database"])
            report = json.loads((directory / f"trivy-{suffix}.json").read_text())
            if SCANNER["blocking_vulnerabilities"](report, item["config_digest"], item["packages"]):
                raise ValueError("Candidate has blocking vulnerabilities")
        if seen != expected:
            raise ValueError("Incomplete release scan evidence")
        validate_runtime(directory, version, f"linux/{arch}", revision, images)


def preflight(items, inspect=CANDIDATES["digest"]):
    # Preflight every immutable tag before changing any public tag.
    existing = {item["reference"]: inspect(item["reference"]) for item in items}
    for item in items:
        value = existing[item["reference"]]
        if item["immutable"] and value not in (None, item["digest"]):
            raise ValueError(f'Immutable tag conflicts with tested digest: {item["reference"]}')
    return existing


def promote(items, journal, inspect=CANDIDATES["digest"], run=subprocess.run):
    existing = preflight(items, inspect)
    completed = []
    for item in items:
        reference, value = item["reference"], item["digest"]
        if existing[reference] != value:
            # A single index source is copied intact, including SBOM/provenance.
            run(["docker", "buildx", "imagetools", "create", "--tag", reference,
                 f'{reference.rsplit(":", 1)[0]}@{value}'], check=True)
        if inspect(reference) != value:
            raise ValueError(f"Registry did not retain the expected digest: {reference}")
        completed.append(item)
        journal.write_text(json.dumps(dict(updated_at=datetime.now(timezone.utc).isoformat(),
                                            completed=completed), indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="joaopinto14/production")
    parser.add_argument("--version", required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--aliases", choices=["true", "false"], required=True)
    parser.add_argument("--journal", type=Path, default=Path("release-promotion.json"))
    parser.add_argument("--check-only", action="store_true", help="Validate evidence and tag conflicts without writing registry state")
    args = parser.parse_args()
    metadata = json.loads(args.metadata.read_text())
    validate_evidence(args.evidence, args.version, args.repository, metadata, args.revision)
    items = plan(args.repository, args.version, metadata, args.aliases == "true")
    if args.check_only:
        preflight(items)
    else:
        promote(items, args.journal)


if __name__ == "__main__":
    main()
