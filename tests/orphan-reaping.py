#!/usr/bin/env python3
"""Provoke repeated PHP orphan bursts while web/CLI containers remain alive."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
import uuid


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=os.environ.get("ORPHAN_TEST_OUTPUT", "candidate-reports/orphan-reaping.json"))
    parser.add_argument("--expect-leak", action="store_true", help="Negative control against a pre-init image")
    parser.add_argument("--image", help="Test one specific image instead of the six-image matrix")
    parser.add_argument("--docker-init", action="store_true", help="Also exercise Docker --init, including nested init compatibility")
    args = parser.parse_args()
    repository = os.environ.get("IMAGE_NAME", "production")
    version = os.environ.get("VERSION", Path("VERSION").read_text().strip())
    images = [args.image] if args.image else [
        f"{repository}:{version}-{prefix}php{php}"
        for prefix in ("", "laravel-") for php in ("8.3", "8.4", "8.5")]
    fixture = Path("tests/orphan-burst.php").resolve()
    evidence = []
    for image in images:
        image_info = json.loads(docker("image", "inspect", image))[0]
        if not args.expect_leak:
            result = subprocess.run(["docker", "run", "--rm", "--no-healthcheck", image_info["Id"],
                                     "php", "-r", "exit(7);"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
            assert result.returncode == 7, "CLI exit code was not preserved: " + result.stderr
        for mode in (("cli",) if args.expect_leak else ("cli", "web")):
            name = "production-orphans-" + uuid.uuid4().hex[:12]
            worker = None
            try:
                command = ["run", "-d", "--name", name, "--read-only", "--cap-drop", "ALL",
                           "--security-opt", "no-new-privileges:true", "--pids-limit", "512",
                           "-e", "DOCUMENT_ROOT=/var/www/html",
                           "--tmpfs", "/tmp:rw,nosuid,nodev,noexec,size=32m,mode=1777",
                           "--tmpfs", "/run/production:rw,nosuid,nodev,noexec,size=16m,mode=0755,uid=10001,gid=10001",
                           "--mount", f"type=bind,src={fixture},dst=/orphan-burst.php,readonly"]
                if args.docker_init:
                    command.append("--init")
                if mode == "cli":
                    command += ["--no-healthcheck", image_info["Id"], "php", "/orphan-burst.php", "5", "40"]
                else:
                    command += [image_info["Id"]]
                docker(*command)
                if mode == "web":
                    worker = subprocess.Popen(["docker", "exec", name, "php", "/orphan-burst.php", "5", "40"],
                                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
                deadline = time.monotonic() + 120
                while True:
                    completed = subprocess.run(["docker", "exec", name, "test", "-f", "/tmp/production-orphan-report.json"],
                                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    if completed.returncode == 0:
                        break
                    if time.monotonic() >= deadline or docker("inspect", "--format", "{{.State.Running}}", name) != "true":
                        raise AssertionError("Orphan workload did not finish: " + docker("logs", name))
                    if worker and worker.poll() is not None:
                        raise AssertionError("Web fixture exited: " + worker.stderr.read())
                    time.sleep(0.25)
                report = json.loads(docker("exec", name, "cat", "/tmp/production-orphan-report.json"))
                assert report["created"] == 200
                time.sleep(1)
                with Path("tests/zombie-check.sh").open() as check:
                    result = subprocess.run(["docker", "exec", "-i", name, "sh", "-s"], stdin=check, capture_output=True, text=True)
                assert (result.returncode != 0) == args.expect_leak, (image, mode, result.stderr)
                init = docker("exec", name, "cat", "/proc/1/comm")
                if not args.expect_leak:
                    assert init.strip() == ("docker-init" if args.docker_init else "tini"), init
                    assert report["controller_pid"] != 1
                assert docker("inspect", "--format", "{{.State.Running}}", name) == "true"
                evidence.append(dict(image=image, image_id=image_info["Id"],
                                     platform=f'{image_info["Os"]}/{image_info["Architecture"]}',
                                     mode=mode, init=init, docker_init=args.docker_init, expected_leak=args.expect_leak,
                                     report=report, persistent_zombies=result.returncode != 0))
                print(f"{image} {mode}: 200 orphans, persistent zombies={'yes (negative control)' if args.expect_leak else '0'}", flush=True)
                if mode == "cli" and not args.expect_leak:
                    docker("stop", "--time", "5", name)
                    assert docker("inspect", "--format", "{{.State.ExitCode}}", name) == "143", "CLI TERM was not forwarded"
                if mode == "web":
                    docker("exec", name, "wget", "-q", "-T", "2", "-O", "/dev/null", "http://127.0.0.1:8080/readyz")
                    docker("stop", "--time", "10", name)
                    assert docker("inspect", "--format", "{{.State.ExitCode}}", name) == "0"
            finally:
                subprocess.run(["docker", "rm", "-f", name], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if worker:
                    worker.communicate(timeout=10)
            if args.output:
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
