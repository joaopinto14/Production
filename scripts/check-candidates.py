#!/usr/bin/env python3
"""Inventory and scan local maintenance candidates; never publish images."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import tarfile
import tempfile


TRIVY_IMAGE = "aquasec/trivy:0.76.1@sha256:790fd66d1697395d8693d1acaa1ea702406a20f109b6fc7bac8db623eca6c06c"
PACKAGE_REPORT = runpy.run_path(str(Path(__file__).with_name("package-report.py")))


def base_reference(dockerfile):
    match = re.search(r"^FROM (alpine:[0-9]+\.[0-9]+(?:\.[0-9]+)?@sha256:[0-9a-f]{64})$", dockerfile, re.MULTILINE)
    if match is None:
        raise ValueError("Expected a literal Alpine branch pinned by SHA256 index digest")
    return match[1]


def check_platforms(manifest):
    platforms = {
        (item.get("platform", {}).get("os"), item.get("platform", {}).get("architecture"))
        for item in manifest.get("manifests", [])
        if item.get("annotations", {}).get("vnd.docker.reference.type") != "attestation-manifest"
    }
    if not {("linux", "amd64"), ("linux", "arm64")} <= platforms:
        raise ValueError("The base digest must identify an index with amd64 and arm64 images")


def check_base_layers(base_layers, image_layers):
    if not base_layers or image_layers[:len(base_layers)] != base_layers:
        raise ValueError("Candidate was not built from the pinned base layers")


def archive_config_digest(path, image_info):
    # Modern Docker stores may identify an image by index digest; Trivy reports
    # its configuration digest. Derive the latter from the actual saved archive.
    matches = []
    with tarfile.open(path) as archive:
        for item in json.load(archive.extractfile("manifest.json")):
            data = archive.extractfile(item["Config"]).read()
            config = json.loads(data)
            if (config.get("os"), config.get("architecture")) != (image_info["Os"], image_info["Architecture"]):
                continue
            if config.get("rootfs", {}).get("diff_ids") != image_info["RootFS"]["Layers"]:
                raise ValueError("Saved archive does not match the inventoried image layers")
            matches.append("sha256:" + hashlib.sha256(data).hexdigest())
    if len(matches) != 1:
        raise ValueError("Expected exactly one configuration for the inventoried platform")
    return matches[0]


def check_database(metadata, now=None):
    now = now or datetime.now(timezone.utc)
    if metadata.get("Version") != 2:
        raise ValueError("Unexpected vulnerability database schema")
    for field in ("UpdatedAt", "DownloadedAt"):
        stamp = datetime.fromisoformat(metadata[field].replace("Z", "+00:00"))
        age = (now - stamp).total_seconds()
        if not -300 <= age <= 48 * 3600:
            raise ValueError(f"Missing, future or stale database {field} (maximum 48 hours)")


def blocking_vulnerabilities(report, image_id, expected_packages):
    if report.get("SchemaVersion") != 2 or report.get("ArtifactType") != "container_image":
        raise ValueError("Unexpected or incomplete Trivy image report")
    metadata = report.get("Metadata", {})
    if metadata.get("ImageID") != image_id:
        raise ValueError("Scan does not identify the inventoried image")
    os_info = metadata.get("OS", {})
    if os_info.get("Family") != "alpine" or os_info.get("EOSL"):
        raise ValueError("Missing Alpine identification or end-of-support OS")
    results = report.get("Results", [])
    if not any(item.get("Class") == "os-pkgs" and item.get("Packages") for item in results):
        raise ValueError("Scan has no operating-system package inventory")
    packages = {}
    for item in results:
        if item.get("Class") != "os-pkgs":
            continue
        for package in item.get("Packages", []):
            name, version = package["Name"], package["Version"]
            if name in packages:
                raise ValueError("Duplicate package in scan inventory")
            packages[name] = version
    if not expected_packages or packages != expected_packages:
        raise ValueError("Scan package names/versions do not match the complete APK inventory")
    if report.get("Trivy", {}).get("Version") != "0.76.1":
        raise ValueError("Unexpected scanner version")
    stamp = datetime.fromisoformat(report["CreatedAt"].replace("Z", "+00:00"))
    if not -300 <= (datetime.now(timezone.utc) - stamp).total_seconds() <= 24 * 3600:
        raise ValueError("Stale or future scan report")
    return [
        vulnerability
        for item in results
        for vulnerability in item.get("Vulnerabilities", []) or []
        if vulnerability.get("Severity") in ("HIGH", "CRITICAL")
        and vulnerability.get("FixedVersion", "").strip()
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="production-candidate")
    parser.add_argument("--version", default=Path("VERSION").read_text().strip())
    parser.add_argument("--platform", required=True, choices=["linux/amd64", "linux/arm64"])
    parser.add_argument("--output", type=Path, default=Path("candidate-reports"))
    parser.add_argument("--metadata", type=Path, help="Scan exact registry digests from Bake metadata and tag them locally for tests")
    parser.add_argument("--registry-repository", default="joaopinto14/production")
    parser.add_argument("--revision", help="Require the release source revision in every candidate")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # A failed invocation cannot accidentally reuse a previous clean report.
    for path in output.glob("trivy-*.json"):
        path.unlink()
    (output / "inventory.json").unlink(missing_ok=True)
    metadata = json.loads(args.metadata.read_text()) if args.metadata else None
    base = base_reference(Path("Dockerfile").read_text())
    manifest = json.loads(subprocess.check_output(
        ["docker", "buildx", "imagetools", "inspect", "--raw", base], text=True))
    check_platforms(manifest)
    (output / "base-index.json").write_text(json.dumps(manifest, indent=2) + "\n")
    base_platform = PACKAGE_REPORT["platform_reference"](base, args.platform)
    subprocess.run(["docker", "pull", "--platform", args.platform, base_platform],
                   check=True, stdout=subprocess.DEVNULL)
    base_info = json.loads(subprocess.check_output(["docker", "image", "inspect", base_platform], text=True))[0]
    base_layers = base_info["RootFS"]["Layers"]
    evidence = dict(version=args.version, platform=args.platform, base_reference=base,
                    base_platform_reference=base_platform, base_image_id=base_info["Id"],
                    scanner=TRIVY_IMAGE, created_at=datetime.now(timezone.utc).isoformat(), images=[])
    blocked = False
    with tempfile.TemporaryDirectory(prefix="production-scan-") as directory:
        temporary = Path(directory)
        cache = temporary / "cache"
        cache.mkdir()
        for variant in ("generic", "laravel"):
            for php in ("8.3", "8.4", "8.5"):
                suffix = f'{"laravel-" if variant == "laravel" else ""}php{php}'
                reference = f"{args.repository}:{args.version}-{suffix}"
                if metadata is not None:
                    target = f'{"laravel-" if variant == "laravel" else ""}php{php.replace(".", "")}-release'
                    digest = metadata[target]["containerimage.digest"]
                    if re.fullmatch(r"sha256:[0-9a-f]{64}", digest) is None:
                        raise ValueError("Invalid candidate registry digest")
                    reference = f"{args.registry_repository}@{digest}"
                print(f"Inventory and scan: {reference} ({args.platform})", flush=True)
                inventory = PACKAGE_REPORT["inventory"](reference, args.platform, metadata is None)
                image_id = inventory["image_id"]
                info = json.loads(subprocess.check_output(["docker", "image", "inspect", image_id], text=True))[0]
                if metadata is not None:
                    subprocess.run(["docker", "tag", image_id, f"{args.repository}:{args.version}-{suffix}"], check=True)
                check_base_layers(base_layers, info["RootFS"]["Layers"])
                revision = info["Config"].get("Labels", {}).get("org.opencontainers.image.revision")
                if args.revision and revision != args.revision:
                    raise ValueError("Candidate source revision does not match the release")
                record = dict(variant=variant, php=php, **inventory)
                record["revision"] = revision
                evidence["images"].append(record)
                # Save inventories even if the scanner/database fails afterwards.
                (output / "inventory.json").write_text(json.dumps(evidence, indent=2) + "\n")
                archive = temporary / "image.tar"
                subprocess.run(["docker", "image", "save", "--output", str(archive), image_id], check=True)
                record["config_digest"] = archive_config_digest(archive, info)
                (output / "inventory.json").write_text(json.dumps(evidence, indent=2) + "\n")
                filename = f"trivy-{suffix}.json"
                subprocess.run([
                    "docker", "run", "--rm", "--user", f"{os.getuid()}:{os.getgid()}",
                    "--mount", f"type=bind,src={temporary},dst=/input,readonly",
                    "--mount", f"type=bind,src={output},dst=/reports",
                    "--mount", f"type=bind,src={cache},dst=/cache", TRIVY_IMAGE,
                    "--cache-dir", "/cache", "image", "--input", "/input/image.tar",
                    "--scanners", "vuln", "--list-all-pkgs", "--format", "json",
                    "--output", f"/reports/{filename}", "--exit-code", "0",
                ], check=True)
                database = json.loads((cache / "db/metadata.json").read_text())
                check_database(database)
                record["database"] = database
                findings = blocking_vulnerabilities(json.loads((output / filename).read_text()),
                                                   record["config_digest"], inventory["packages"])
                (output / "inventory.json").write_text(json.dumps(evidence, indent=2) + "\n")
                for item in findings:
                    print(f'{suffix}: {item["Severity"]} {item["VulnerabilityID"]} '
                          f'{item["PkgName"]}: {item["InstalledVersion"]} -> {item["FixedVersion"]}')
                blocked = blocked or bool(findings)
    if blocked:
        raise SystemExit("Candidate rejected: fixable HIGH/CRITICAL vulnerabilities; see saved reports")
    print("All six inventories and vulnerability reports passed the candidate policy.")


if __name__ == "__main__":
    main()
