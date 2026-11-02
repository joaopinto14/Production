#!/usr/bin/env python3
"""Local audit probes. Uses synthetic fixtures and only its own containers."""
import concurrent.futures
import http.client
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import uuid


OUTPUT = Path(__file__).resolve().parent
RESULTS = {}
CONTAINERS = []
PREFIX = "production-audit-" + uuid.uuid4().hex[:8]


def docker(*args, check=True, timeout=40):
    result = subprocess.run(["docker", *args], text=True, capture_output=True, timeout=timeout)
    if check and result.returncode:
        raise RuntimeError(f"docker {args[0]} failed: {result.stderr[:1200]}")
    return result


def request(port, path="/", body=None, headers=None, timeout=8):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
    try:
        connection.request("POST" if body is not None else "GET", path, body=body, headers=headers or {})
        response = connection.getresponse()
        data = response.read()
        return dict(status=response.status, body=data[:300].decode(errors="replace"), length=len(data))
    except Exception as error:
        return dict(error=f"{type(error).__name__}: {error}")
    finally:
        connection.close()


def start(image, app, suffix, flags=(), wait=True):
    name = f"{PREFIX}-{suffix}"
    CONTAINERS.append(name)
    docker("run", "-d", "--name", name, "--publish", "127.0.0.1::8080",
           "--mount", f"type=bind,src={app},dst=/var/www/html,readonly", *flags, image)
    if not wait:
        return name, None
    for _ in range(40):
        info = json.loads(docker("inspect", name).stdout)[0]
        if info["State"]["Status"] == "exited":
            raise RuntimeError(docker("logs", name).stdout + docker("logs", name).stderr)
        bindings = info["NetworkSettings"]["Ports"].get("8080/tcp") or []
        if bindings and info["State"].get("Health", {}).get("Status") == "healthy":
            return name, int(bindings[0]["HostPort"])
        time.sleep(0.25)
    raise RuntimeError(f"Audit container did not become healthy: {name}")


def main():
    with tempfile.TemporaryDirectory(prefix=PREFIX) as directory:
        app = Path(directory)
        app.chmod(0o755)
        (app / "public").mkdir()
        index = '''<?php
header('Content-Type: application/json');
if (isset($_GET['slow'])) {
    file_put_contents('/tmp/audit-request-started', 'started');
    sleep(4);
}
echo json_encode(['ok'=>true, 'bytes'=>strlen(file_get_contents('php://input'))]);
'''
        for root in (app, app / "public"):
            (root / "index.php").write_text(index)
            for name in ("source.php", "source.PHP", "source.pHp", "source.php.bak", "source.php~", "source.phtml"):
                (root / name).write_text('<?php /* AUDIT_SOURCE_MARKER */ echo "EXECUTED";')
            (root / ".env").write_text("AUDIT_SYNTHETIC_SECRET=not-a-real-secret")
            (root / ".well-known" / ".private").mkdir(parents=True)
            (root / ".well-known" / "acme.txt").write_text("acme-ok")
            (root / ".well-known" / ".private" / "marker.txt").write_text("AUDIT_HIDDEN_MARKER")
            for path in root.rglob("*"):
                path.chmod(0o755 if path.is_dir() else 0o644)

        for variant in ("generic", "laravel"):
            image = f'production-candidate:2.0.3-{"laravel-" if variant == "laravel" else ""}php8.5'
            name, port = start(image, app, variant)
            paths = ("/", "/source.php", "/source.PHP", "/source.pHp", "/source.php.bak", "/source.php~",
                     "/source.phtml", "/.env", "/%2eenv", "/index.php/.private/marker",
                     "/.well-known/acme.txt", "/.well-known/.private/marker.txt", "/missing.php")
            RESULTS[f"http_{variant}"] = {path: request(port, path) for path in paths}
            if variant == "generic":
                docker("exec", name, "mv", "/run/production/php/php-fpm.sock", "/run/production/php/php-fpm.audit-held")
                RESULTS["health_without_fpm_socket"] = dict(health=request(port, "/healthz"), php=request(port, "/"))
                docker("exec", name, "mv", "/run/production/php/php-fpm.audit-held", "/run/production/php/php-fpm.sock")
                with concurrent.futures.ThreadPoolExecutor() as pool:
                    future = pool.submit(request, port, "/?slow=1", timeout=10)
                    for _ in range(50):
                        if docker("exec", name, "test", "-f", "/tmp/audit-request-started", check=False).returncode == 0:
                            break
                        time.sleep(0.1)
                    beginning = time.monotonic()
                    docker("kill", "--signal=TERM", name)
                    response = future.result()
                    docker("wait", name)
                    RESULTS["graceful_in_flight"] = dict(response=response, seconds=round(time.monotonic()-beginning, 2),
                                                         exit_code=json.loads(docker("inspect", name).stdout)[0]["State"]["ExitCode"])
            docker("rm", "-f", name)

        generic = "production-candidate:2.0.3-php8.5"
        hardening = ["--read-only", "--cap-drop", "ALL", "--security-opt", "no-new-privileges:true"]
        wrong = [*hardening, "--tmpfs", "/run/production:rw,nosuid,nodev,noexec,size=16m",
                 "--tmpfs", "/tmp:rw,nosuid,nodev,noexec,size=16m"]
        name, _ = start(generic, app, "readme", wrong, wait=False)
        docker("wait", name)
        info = json.loads(docker("inspect", name).stdout)[0]
        logs = docker("logs", name)
        RESULTS["readme_readonly"] = dict(exit_code=info["State"]["ExitCode"], logs=(logs.stdout+logs.stderr)[:900])

        correct = [*hardening, "--tmpfs", "/run/production:rw,nosuid,nodev,noexec,size=16m,mode=0755,uid=10001,gid=10001",
                   "--tmpfs", "/tmp:rw,nosuid,nodev,noexec,size=32m,mode=1777", "-e", "UPLOAD_MAX_SIZE=32M"]
        name, port = start(generic, app, "capacity", correct)
        RESULTS["tmpfs_capacity"] = dict(small=request(port, body=b"x"*1024),
                                         large=request(port, body=b"x"*(17*1024*1024), timeout=15))
        logs = docker("logs", name)
        RESULTS["tmpfs_capacity"]["disk_errors"] = [line for line in (logs.stdout+logs.stderr).splitlines()
                                                        if "No space left" in line][:3]
        docker("rm", "-f", name)

        name, _ = start(generic, app, "blocked-shutdown")
        docker("exec", name, "sh", "-c", 'kill -STOP "$(cat /run/production/nginx/nginx.pid)"')
        docker("kill", "--signal=TERM", name)
        time.sleep(3)
        state = json.loads(docker("inspect", name).stdout)[0]["State"]
        RESULTS["blocked_shutdown"] = dict(state_after_3_seconds=state["Status"])
        docker("stop", "--time", "1", name)
        RESULTS["blocked_shutdown"]["exit_after_forced_stop"] = json.loads(docker("inspect", name).stdout)[0]["State"]["ExitCode"]

        # Fault injection affects only a temporary PATH wrapper, not Docker itself.
        fake_bin = app / "fake-bin"
        fake_bin.mkdir()
        fake_docker = fake_bin / "docker"
        fake_docker.write_text('#!/bin/sh\nif [ "$1" = image ] && [ "$2" = inspect ]; then exit 0; fi\necho "audit: simulated docker save failure" >&2\nexit 42\n')
        fake_docker.chmod(0o755)
        import os
        result = subprocess.run(["./tests/size-budget.sh"], capture_output=True, text=True,
                                env={**os.environ, "PATH": str(fake_bin)+os.pathsep+os.environ["PATH"]})
        RESULTS["size_false_success"] = dict(exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)

        # Never read real credentials: assess ignore rules with a synthetic context.
        context = app / "context"
        context.mkdir()
        shutil.copyfile(".dockerignore", context / ".dockerignore")
        for marker in (".aws/audit-marker", ".codex/audit-marker", ".agents/audit-marker", ".env"):
            path = context / marker
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("AUDIT_SYNTHETIC_CONTEXT_MARKER")
        (context / "Dockerfile").write_text("FROM scratch\nCOPY . /context\n")
        exported = app / "exported"
        docker("buildx", "build", "--output", f"type=local,dest={exported}", str(context), timeout=60)
        RESULTS["context_markers"] = {marker: (exported/"context"/marker).exists()
                                      for marker in (".aws/audit-marker", ".codex/audit-marker", ".agents/audit-marker", ".env")}


if __name__ == "__main__":
    try:
        main()
    finally:
        for name in CONTAINERS:
            docker("rm", "-f", name, check=False)
        (OUTPUT / "probes.json").write_text(json.dumps(RESULTS, indent=2)+"\n")
        print(json.dumps(RESULTS, indent=2))
