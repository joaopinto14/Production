#!/usr/bin/env python3
"""Run release suites without rebuilding and retain logs and image identities."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

SUITES = ("test-all", "release-contract", "real-generic", "real-laravel", "restart-stability")


def snapshot(repository, version, platform, revision):
    images = {}
    for prefix in ("", "laravel-"):
        for php in ("8.3", "8.4", "8.5"):
            suffix = f"{prefix}php{php}"
            reference = f"{repository}:{version}-{suffix}"
            info = json.loads(subprocess.check_output(["docker", "image", "inspect", reference], text=True))[0]
            labels = info["Config"].get("Labels", {})
            if (f'{info["Os"]}/{info["Architecture"]}' != platform
                    or labels.get("org.opencontainers.image.version") != version
                    or (revision and labels.get("org.opencontainers.image.revision") != revision)):
                raise ValueError("Candidate platform/version/revision mismatch: " + reference)
            images[suffix] = info["Id"]
    return images


def run_suite(name, output, env):
    path = output / f"{name}.log"
    started = time.monotonic()
    with path.open("wb") as log:
        process = subprocess.Popen([f"./tests/{name}.sh"], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        try:
            for line in process.stdout:
                log.write(line)
                log.flush()
                sys.stdout.buffer.write(line)
                sys.stdout.buffer.flush()
            code = process.wait()
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait()
            process.stdout.close()
    return dict(name=name, exit_code=code, seconds=round(time.monotonic() - started, 2),
                log=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default=os.environ.get("IMAGE_NAME", "production"))
    parser.add_argument("--version", default=os.environ.get("VERSION", Path("VERSION").read_text().strip()))
    parser.add_argument("--revision", default=os.environ.get("REVISION"))
    parser.add_argument("--platform", required=True, choices=("linux/amd64", "linux/arm64"))
    parser.add_argument("--output", type=Path, default=Path("candidate-reports"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    path = args.output / "runtime-tests.json"
    path.unlink(missing_ok=True)
    env = dict(os.environ, IMAGE_NAME=args.repository, VERSION=args.version, SKIP_BUILD="1",
               ORPHAN_TEST_OUTPUT=str(args.output / "orphan-reaping.json"))
    original = snapshot(args.repository, args.version, args.platform, args.revision)
    result = dict(version=args.version, revision=args.revision, platform=args.platform,
                  started_at=datetime.now(timezone.utc).isoformat(), images=original,
                  status="running", suites=[])
    path.write_text(json.dumps(result, indent=2) + "\n")
    try:
        for name in SUITES:
            record = run_suite(name, args.output, env)
            result["suites"].append(record)
            path.write_text(json.dumps(result, indent=2) + "\n")
            if record["exit_code"] != 0:
                raise RuntimeError(f'{name} failed with exit code {record["exit_code"]}; see {record["log"]}')
            if snapshot(args.repository, args.version, args.platform, args.revision) != original:
                raise RuntimeError("Candidate image IDs changed during validation")
        result["status"] = "passed"
    except BaseException as error:
        result["status"] = "failed"
        result["error"] = str(error)
        raise
    finally:
        result["completed_at"] = datetime.now(timezone.utc).isoformat()
        path.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
