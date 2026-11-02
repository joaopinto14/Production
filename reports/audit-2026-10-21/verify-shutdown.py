#!/usr/bin/env python3
"""Confirm request draining independently of the health/socket probes."""
import concurrent.futures
import json
from pathlib import Path
import runpy
import tempfile
import time


ROOT = Path(__file__).resolve().parent
HELPERS = runpy.run_path(str(ROOT / "verify.py"))
docker = HELPERS["docker"]
request = HELPERS["request"]
results = {}

try:
    with tempfile.TemporaryDirectory(prefix="production-audit-drain-") as directory:
        app = Path(directory)
        app.chmod(0o755)
        (app / "index.php").write_text('''<?php
file_put_contents('/tmp/audit-drain-started', 'yes');
sleep(5);
echo "request-completed";
''')
        for mode in ("runtime_TERM", "fpm_QUIT", "nginx_QUIT"):
            name, port = HELPERS["start"]("production-candidate:2.0.3-php8.5", app, mode.lower())
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(request, port, "/", timeout=12)
                started = False
                for _ in range(50):
                    if docker("exec", name, "test", "-f", "/tmp/audit-drain-started", check=False).returncode == 0:
                        started = True
                        break
                    time.sleep(0.1)
                if not started:
                    raise RuntimeError("Request did not reach PHP; no shutdown conclusion possible")
                beginning = time.monotonic()
                if mode == "runtime_TERM":
                    docker("kill", "--signal=TERM", name)
                else:
                    path = "/run/production/php/php-fpm.pid" if mode == "fpm_QUIT" else "/run/production/nginx/nginx.pid"
                    docker("exec", name, "sh", "-c", f'kill -QUIT "$(cat {path})"')
                response = future.result()
                docker("wait", name)
                info = json.loads(docker("inspect", name).stdout)[0]
                logs = docker("logs", name)
                results[mode] = dict(request_started=started, response=response,
                                     seconds=round(time.monotonic()-beginning, 2),
                                     exit_code=info["State"]["ExitCode"], logs=logs.stdout+logs.stderr)
finally:
    for name in HELPERS["CONTAINERS"]:
        docker("rm", "-f", name, check=False)
    (ROOT / "shutdown.json").write_text(json.dumps(results, indent=2)+"\n")
    print(json.dumps(results, indent=2))
