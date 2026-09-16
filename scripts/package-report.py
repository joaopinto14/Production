#!/usr/bin/env python3
"""Compare actual Alpine package inventories without executing image contents.

Only Python's standard library and the Docker CLI are required on the host.
Registry mode pulls each platform; --local makes a clearly labelled local report.
"""
import argparse
import io
import json
from pathlib import Path
import subprocess
import tarfile


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def parse_inventory(data):
    packages = {}
    for block in data.split("\n\n"):
        fields = dict(line.split(":", 1) for line in block.splitlines() if ":" in line)
        if "P" in fields and "V" in fields:
            packages[fields["P"]] = fields["V"]
    if not packages:
        raise ValueError("Empty Alpine package inventory")
    return packages


def changes(before, after):
    return [dict(package=name, previous=before.get(name), current=after.get(name),
                 change="added" if name not in before else "removed" if name not in after else "changed")
            for name in sorted(before.keys() | after.keys()) if before.get(name) != after.get(name)]


def platform_reference(reference, platform):
    """Pull a child manifest, not one shared index under multiple platforms.

    Classic Docker image stores cannot bind the same index digest to both
    architecture-specific images. Resolving in the registry also avoids pulling
    BuildKit attestation manifests (normally marked unknown/unknown).
    """
    manifest = json.loads(run("docker", "buildx", "imagetools", "inspect", "--raw", reference))
    if "manifests" not in manifest:
        return reference  # Single-platform manifest; inventory verifies its OS/arch.
    parts = platform.split("/")
    if len(parts) not in (2, 3):
        raise ValueError(f"Expected os/architecture[/variant], got {platform}")
    matches = []
    for descriptor in manifest["manifests"]:
        candidate = descriptor.get("platform", {})
        if (candidate.get("os"), candidate.get("architecture")) != tuple(parts[:2]):
            continue
        if len(parts) == 3 and candidate.get("variant") != parts[2]:
            continue
        if descriptor.get("annotations", {}).get("vnd.docker.reference.type") == "attestation-manifest":
            continue
        matches.append(descriptor["digest"])
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one image manifest for {platform} in {reference}; found {len(matches)}")
    # Strip a tag/digest without stripping a registry port.
    name = reference.split("@", 1)[0]
    parent, separator, leaf = name.rpartition("/")
    repository = parent + separator + leaf.split(":", 1)[0]
    return f"{repository}@{matches[0]}"


def inventory(reference, platform, local):
    resolved_reference = reference if local else platform_reference(reference, platform)
    if not local:
        subprocess.run(["docker", "pull", "--platform", platform, resolved_reference], check=True, stdout=subprocess.DEVNULL)
    container = run("docker", "create", "--platform", platform, "--entrypoint", "/bin/true", resolved_reference)
    try:
        image_id = run("docker", "inspect", "--format", "{{.Image}}", container)
        info = json.loads(run("docker", "image", "inspect", image_id))[0]
        actual = f'{info["Os"]}/{info["Architecture"]}'
        expected = "/".join(platform.split("/")[:2])
        if actual != expected:
            raise ValueError(f"Platform mismatch for {reference}: expected {platform}, got {actual}")
        archive = subprocess.check_output(["docker", "cp", f"{container}:/lib/apk/db/installed", "-"])
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            members = [m for m in tar.getmembers() if m.isfile()]
            if len(members) != 1:
                raise ValueError("Unexpected APK inventory archive")
            packages = parse_inventory(tar.extractfile(members[0]).read().decode())
        return dict(reference=reference, resolved_reference=resolved_reference, image_id=image_id,
                    registry_digests=info.get("RepoDigests", []), packages=packages)
    finally:
        subprocess.run(["docker", "rm", container], check=True, stdout=subprocess.DEVNULL)


def markdown(report):
    lines = ["# Package changes", "", f'Comparison: **{report["previous_version"]} → {report["version"]}**.', "",
             f'Evidence: {report["scope"]}. Inventories are read from `/lib/apk/db/installed`; exact image IDs and registry digests are recorded in the accompanying JSON.', "",
             "Changed versions are reported as observed, including any downgrade. This inventory does not establish CVE remediation; no CVE fix is claimed without a separate vulnerability assessment.", ""]
    for item in report["images"]:
        lines += [f'## {item["variant"]} · PHP {item["php"]} · {item["platform"]}', ""]
        if not item["changes"]:
            lines += ["No package version changes detected.", ""]
            continue
        lines += ["| Package | Previous | New | Change |", "|---|---|---|---|"]
        for change in item["changes"]:
            lines.append(f'| `{change["package"]}` | `{change["previous"] or "—"}` | `{change["current"] or "—"}` | {change["change"]} |')
        lines.append("")
    return "\n".join(lines)


def write_report(report, output):
    output.parent.mkdir(parents=True, exist_ok=True)
    # Append extensions: version numbers in filenames contain dots.
    Path(str(output) + ".json").write_text(json.dumps(report, indent=2) + "\n")
    Path(str(output) + ".md").write_text(markdown(report))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--previous-version", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--repository", default="joaopinto14/production")
    parser.add_argument("--platforms", nargs="+", default=["linux/amd64", "linux/arm64"])
    parser.add_argument("--metadata", type=Path, help="Buildx Bake metadata identifying the exact published image digests")
    parser.add_argument("--local", action="store_true", help="Use existing local images; do not pull")
    parser.add_argument("--output", type=Path, required=True, help="Output path without .json/.md suffix")
    args = parser.parse_args()
    metadata = json.loads(args.metadata.read_text()) if args.metadata else None
    report = dict(previous_version=args.previous_version, version=args.version,
                  scope="local build comparison (not a published release inventory)" if args.local else "registry image comparison",
                  images=[])
    for variant in ("generic", "laravel"):
        for php in ("8.3", "8.4", "8.5"):
            suffix = f'{"laravel-" if variant == "laravel" else ""}php{php}'
            current_ref = f"{args.repository}:{args.version}-{suffix}"
            if metadata is not None:
                target = f'{"laravel-" if variant == "laravel" else ""}php{php.replace(".", "")}-release'
                current_ref = f'{args.repository}@{metadata[target]["containerimage.digest"]}'
            for platform in args.platforms:
                print(f"Comparing {suffix} on {platform}", flush=True)
                before = inventory(f"{args.repository}:{args.previous_version}-{suffix}", platform, args.local)
                after = inventory(current_ref, platform, args.local)
                report["images"].append(dict(variant=variant, php=php, platform=platform, before=before, after=after,
                                             changes=changes(before["packages"], after["packages"])))
    write_report(report, args.output)


if __name__ == "__main__":
    main()
