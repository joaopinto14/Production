#!/usr/bin/env python3
"""Audit published images on both architectures without starting their contents."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).resolve().parent / "published"
REPORT = runpy.run_path(str(ROOT / "scripts/package-report.py"))
CHECK = runpy.run_path(str(ROOT / "scripts/check-candidates.py"))


def main():
    OUTPUT.mkdir(exist_ok=True)
    evidence = {"version": "2.0.3", "scope": "published registry images; no image contents executed", "images": []}
    with tempfile.TemporaryDirectory(prefix="production-published-audit-") as directory:
        temporary = Path(directory)
        cache = temporary / "cache"
        cache.mkdir()
        for variant in ("generic", "laravel"):
            for php in ("8.3", "8.4", "8.5"):
                suffix = ("laravel-" if variant == "laravel" else "") + "php" + php
                for architecture in ("amd64", "arm64"):
                    platform = "linux/" + architecture
                    reference = "joaopinto14/production:2.0.3-" + suffix
                    print(f"Published inventory and scan: {reference} {platform}", flush=True)
                    inventory = REPORT["inventory"](reference, platform, False)
                    info = json.loads(subprocess.check_output(["docker", "image", "inspect", inventory["image_id"]], text=True))[0]
                    archive = temporary / "image.tar"
                    subprocess.run(["docker", "image", "save", "--output", str(archive), inventory["image_id"]], check=True)
                    record = dict(variant=variant, php=php, platform=platform, **inventory,
                                  config_digest=CHECK["archive_config_digest"](archive, info))
                    evidence["images"].append(record)
                    (OUTPUT / "inventory.json").write_text(json.dumps(evidence, indent=2)+"\n")
                    filename = f"trivy-{suffix}-{architecture}.json"
                    subprocess.run([
                        "docker", "run", "--rm", "--user", f"{os.getuid()}:{os.getgid()}",
                        "--mount", f"type=bind,src={temporary},dst=/input,readonly",
                        "--mount", f"type=bind,src={OUTPUT},dst=/reports",
                        "--mount", f"type=bind,src={cache},dst=/cache", CHECK["TRIVY_IMAGE"],
                        "--cache-dir", "/cache", "image", "--input", "/input/image.tar",
                        "--scanners", "vuln", "--list-all-pkgs", "--format", "json",
                        "--output", "/reports/"+filename, "--exit-code", "0",
                    ], check=True)
                    scan = json.loads((OUTPUT / filename).read_text())
                    blocking = CHECK["blocking_vulnerabilities"](scan, record["config_digest"])
                    record["fixable_high_critical"] = len(blocking)
                    (OUTPUT / "inventory.json").write_text(json.dumps(evidence, indent=2)+"\n")
                    print(f"{suffix} {architecture}: {len(blocking)} fixable HIGH/CRITICAL", flush=True)


if __name__ == "__main__":
    main()
