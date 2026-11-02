#!/usr/bin/env python3
"""Read registry artifacts and verify release platforms, identity and attestations."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import runpy
import subprocess

CANDIDATES = runpy.run_path(str(Path(__file__).with_name("release-candidates.py")))
PLATFORMS = ("linux/amd64", "linux/arm64")


def inspect(reference, field):
    return json.loads(subprocess.check_output(
        ["docker", "buildx", "imagetools", "inspect", reference,
         "--format", "{{json ." + field + "}}"], text=True, timeout=180))


def validate_index(manifest, expected_digest):
    if manifest.get("digest") != expected_digest:
        raise ValueError("Registry index differs from the candidate digest")
    platforms = {}
    for item in manifest.get("manifests", []):
        if item.get("annotations", {}).get("vnd.docker.reference.type") == "attestation-manifest":
            continue
        platform = item.get("platform", {})
        name = f'{platform.get("os")}/{platform.get("architecture")}'
        if name not in PLATFORMS or name in platforms:
            raise ValueError("Unexpected or duplicate release platform: " + name)
        if re.fullmatch(r"sha256:[0-9a-f]{64}", item.get("digest", "")) is None:
            raise ValueError("Invalid platform manifest digest")
        platforms[name] = item["digest"]
    if set(platforms) != set(PLATFORMS):
        raise ValueError("Release must contain both amd64 and arm64")
    return platforms


def validate_contents(images, sboms, provenance, version, revision, suffix):
    variant = "laravel" if suffix.startswith("laravel-") else "generic"
    for platform in PLATFORMS:
        image = images.get(platform, {})
        if f'{image.get("os")}/{image.get("architecture")}' != platform:
            raise ValueError("Wrong image configuration platform: " + platform)
        config = image.get("config", {})
        labels = config.get("Labels", {})
        expected = {"org.opencontainers.image.version": version,
                    "org.opencontainers.image.revision": revision,
                    "io.joaopinto.production.variant": variant,
                    "io.joaopinto.production.php-version": suffix[-3:]}
        if any(labels.get(key) != value for key, value in expected.items()):
            raise ValueError("Wrong release identity in configuration: " + platform)
        if config.get("User") != "www":
            raise ValueError("Release must retain its non-root runtime user")
        sbom = (sboms.get(platform) or {}).get("SPDX") or {}
        if (not sbom.get("spdxVersion", "").startswith("SPDX-2.")
                or not sbom.get("documentNamespace") or not sbom.get("packages")):
            raise ValueError("Missing or empty SPDX SBOM: " + platform)
        slsa = (provenance.get(platform) or {}).get("SLSA") or {}
        if not (slsa.get("buildType") or slsa.get("buildDefinition", {}).get("buildType")):
            raise ValueError("Missing SLSA provenance: " + platform)


def verify(repository, version, revision, metadata, published=False, aliases=False, read=inspect):
    targets = list(CANDIDATES["targets"](version))
    if set(metadata) != {target for target, _ in targets}:
        raise ValueError("Expected exactly six release candidates")
    if re.fullmatch(r"[0-9a-f]{40}", revision) is None:
        raise ValueError("Expected a complete source commit SHA")
    evidence = []
    for target, suffix in targets:
        digest = metadata[target]["containerimage.digest"]
        if re.fullmatch(r"sha256:[0-9a-f]{64}", digest) is None:
            raise ValueError("Invalid candidate digest")
        reference = f"{repository}@{digest}"
        manifest = read(reference, "Manifest")
        platforms = validate_index(manifest, digest)
        images, sboms, provenance = (read(reference, field) for field in ("Image", "SBOM", "Provenance"))
        validate_contents(images, sboms, provenance, version, revision, suffix)
        tags = []
        if published:
            tags.append(f"{version}-{suffix}")
            if suffix == "php8.5":
                tags.append(version)
            if aliases:
                tags.append(suffix)
                if suffix in ("php8.5", "laravel-php8.5"):
                    tags.append("latest" if suffix == "php8.5" else "laravel")
        for tag in tags:
            if read(f"{repository}:{tag}", "Manifest").get("digest") != digest:
                raise ValueError("Published tag differs from the tested digest: " + tag)
        evidence.append(dict(target=target, reference=reference, platforms=platforms,
                             tags=tags, manifest=manifest, configurations=images,
                             sbom=sboms, provenance=provenance))
    return dict(version=version, revision=revision, repository=repository,
                created_at=datetime.now(timezone.utc).isoformat(), images=evidence)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="joaopinto14/production")
    parser.add_argument("--version", required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--published", action="store_true", help="Also check all seven public version tags")
    parser.add_argument("--aliases", action="store_true", help="Also check aliases; requires --published")
    parser.add_argument("--output", type=Path, default=Path("release-verification.json"))
    args = parser.parse_args()
    if args.aliases and not args.published:
        parser.error("--aliases requires --published")
    # Never leave an earlier successful result after a failed verification.
    args.output.unlink(missing_ok=True)
    result = verify(args.repository, args.version, args.revision,
                    json.loads(args.metadata.read_text()), args.published, args.aliases)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print("Verified all six registry indexes, both platforms, SPDX SBOMs and SLSA provenance.")


if __name__ == "__main__":
    main()
