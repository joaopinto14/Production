#!/usr/bin/env python3
"""Refuse to publish over existing version tags; registry errors fail closed."""
import argparse
import re
import subprocess


def version_tags(version):
    if re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version) is None:
        raise ValueError("Expected a stable X.Y.Z version")
    return [version] + [f"{version}-{prefix}php{php}"
                        for prefix in ("", "laravel-") for php in ("8.3", "8.4", "8.5")]


def check_tags(repository, version):
    for tag in version_tags(version):
        reference = f"{repository}:{tag}"
        result = subprocess.run(["docker", "buildx", "imagetools", "inspect", reference],
                                capture_output=True, text=True, check=False)
        if result.returncode == 0:
            raise ValueError(f"Version tag already exists: {reference}. Publish a new version.")
        error = result.stderr.strip()
        missing = "manifest unknown" in error.lower() or "no such manifest" in error.lower()
        missing = missing or error.endswith(f"{reference}: not found")
        if not missing:
            raise RuntimeError(f"Cannot establish that {reference} is absent: {error}")
        print(f"Available version tag: {reference}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--repository", default="joaopinto14/production")
    args = parser.parse_args()
    check_tags(args.repository, args.version)
