#!/bin/sh
set -eu

IMAGE="${IMAGE:-production:2.0.0-dev.1-php8.5}"
CONTAINER="production-smoke-$$"
APP_DIR="$(mktemp -d)"
chmod 0755 "${APP_DIR}"

cleanup() {
    docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
    rm -rf "${APP_DIR}"
}
trap cleanup EXIT INT TERM

cat > "${APP_DIR}/index.php" <<'EOF_PHP'
<?php
header('Content-Type: text/plain');
echo 'production-ok';
EOF_PHP
chmod 0644 "${APP_DIR}/index.php"

echo "[1/4] Building ${IMAGE}"
docker build --build-arg VERSION=2.0.0-dev.1 -t "${IMAGE}" .

echo "[2/4] Checking PHP CLI"
docker run --rm "${IMAGE}" php -v

echo "[3/4] Starting web runtime"
docker run -d \
    --name "${CONTAINER}" \
    -v "${APP_DIR}:/var/www/html:ro" \
    "${IMAGE}" >/dev/null

attempt=0
while [ "${attempt}" -lt 20 ]; do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${CONTAINER}" 2>/dev/null || true)"
    if [ "${status}" = "healthy" ]; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done

status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${CONTAINER}")"
[ "${status}" = "healthy" ] || {
    docker logs "${CONTAINER}" >&2 || true
    echo "Smoke test failed: container health is '${status}'." >&2
    exit 1
}

echo "[4/4] Checking HTTP/PHP response"
response="$(docker exec "${CONTAINER}" wget -q -O - http://127.0.0.1/)"
[ "${response}" = "production-ok" ] || {
    echo "Smoke test failed: unexpected response '${response}'." >&2
    exit 1
}

echo "Smoke test passed."
