#!/usr/bin/env python3
"""Exercise an active PHP request, bounded shutdown and invalid deadlines."""
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid


def docker(*args, **kwargs):
    return subprocess.check_output(["docker", *args], text=True, **kwargs).strip()


def wait_for(predicate, seconds=20):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.2)
    raise AssertionError("Deadline exceeded")


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    root.chmod(0o755)
    (root / "index.php").write_text('<?php file_put_contents("/tmp/request-started", "yes"); sleep(5); echo "completed";')
    (root / "index.php").chmod(0o644)
    for image in sys.argv[1:]:
        for mode, timeout in (("drain", "12"), ("stuck", "2"), ("invalid", "bad"),
                              ("zero", "0"), ("large", "301"), ("overflow", "9" * 40)):
            name = "production-drain-" + uuid.uuid4().hex[:12]
            client = None
            try:
                docker("run", "-d", "--name", name, "-e", "SHUTDOWN_TIMEOUT=" + timeout,
                       "-v", f"{root}:/var/www/html:ro", image)
                if mode in ("drain", "stuck"):
                    wait_for(lambda: docker("inspect", "--format", "{{.State.Health.Status}}", name) == "healthy", 60)
                    if mode == "drain":
                        client = subprocess.Popen(["docker", "exec", name, "php", "-r",
                            '$r=file_get_contents("http://127.0.0.1:8080/"); echo $http_response_header[0]."|".$r;'],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                        wait_for(lambda: subprocess.run(["docker", "exec", name, "test", "-f", "/tmp/request-started"],
                                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0)
                    else:
                        docker("exec", name, "sh", "-c", 'kill -STOP "$(cat /run/production/nginx/nginx.pid)"')
                    started = time.monotonic()
                    docker("kill", "--signal=TERM", name)
                    if client:
                        stdout, stderr = client.communicate(timeout=15)
                        assert client.returncode == 0 and stdout == "HTTP/1.1 200 OK|completed", (stdout, stderr)
                    wait_for(lambda: docker("inspect", "--format", "{{.State.Running}}", name) == "false", 16)
                    assert time.monotonic() - started < (8 if mode == "stuck" else 16)
                wait_for(lambda: docker("inspect", "--format", "{{.State.Running}}", name) == "false")
                assert docker("inspect", "--format", "{{.State.ExitCode}}", name) == ("0" if mode == "drain" else "1")
                print(f"{image}: {mode} passed", flush=True)
            finally:
                subprocess.run(["docker", "rm", "-f", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                if client and client.poll() is None:
                    client.kill()
                    client.communicate()
