#!/usr/bin/env python3
"""Probe the ignore policy with synthetic files; never read real credentials."""
from pathlib import Path
import shutil
import subprocess
import tempfile

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    context = root / "context"
    context.mkdir()
    shutil.copyfile(".dockerignore", context / ".dockerignore")
    for name in (".aws/credentials", ".codex/auth.json", ".agents/secret", ".env", ".git/config",
                 "README.md", "reports/secret.json", "unrecognised/token", "app/.env",
                 "entrypoint/.env", "nginx/.aws/credentials", "php/secret.ini"):
        path = context / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("synthetic-secret")
    for name in ("entrypoint/runtime.sh", "nginx/default.conf.template", "php/www.conf"):
        path = context / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("runtime-source")
    (context / "Dockerfile").write_text("FROM scratch\nCOPY . /\n")
    output = root / "output"
    subprocess.run(["docker", "buildx", "build", "--output", f"type=local,dest={output}", str(context)], check=True)
    included = {str(path.relative_to(output)) for path in output.rglob("*") if path.is_file()}
    assert included == {"Dockerfile", "entrypoint/runtime.sh", "nginx/default.conf.template", "php/www.conf"}, included
    print("Synthetic build-context exclusion passed.")
