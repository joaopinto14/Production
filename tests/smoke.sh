#!/bin/sh
set -eu

VERSION="${VERSION:-2.0.0-dev.3}"
PHP_VERSION="${PHP_VERSION:-8.5}"
IMAGE="${IMAGE:-production:${VERSION}-php${PHP_VERSION}}"
CONTAINER="production-smoke-$$"
APP_DIR="$(mktemp -d)"
chmod 0755 "${APP_DIR}"

cleanup() {
    docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
    rm -rf "${APP_DIR}"
}
trap cleanup EXIT INT TERM

case "${PHP_VERSION}" in
    8.3|8.4|8.5) ;;
    *)
        echo "Unsupported PHP_VERSION '${PHP_VERSION}'. Use 8.3, 8.4 or 8.5." >&2
        exit 1
        ;;
esac

cat > "${APP_DIR}/index.php" <<'EOF_PHP'
<?php
header('Content-Type: text/plain');
echo 'production-ok';
EOF_PHP
chmod 0644 "${APP_DIR}/index.php"

echo "[1/6] Building ${IMAGE}"
docker build \
    --build-arg VERSION="${VERSION}" \
    --build-arg PHP_VERSION="${PHP_VERSION}" \
    -t "${IMAGE}" .

echo "[2/6] Checking PHP ${PHP_VERSION} and non-root runtime"
actual_php_version="$(docker run --rm "${IMAGE}" php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')"
[ "${actual_php_version}" = "${PHP_VERSION}" ] || {
    echo "Smoke test failed: expected PHP ${PHP_VERSION}, got ${actual_php_version}." >&2
    exit 1
}
docker run --rm "${IMAGE}" php -v

runtime_uid="$(docker run --rm --entrypoint /usr/bin/id "${IMAGE}" -u)"
[ "${runtime_uid}" != "0" ] || {
    echo "Smoke test failed: image runs as root." >&2
    exit 1
}

echo "[3/6] Checking OPcache"
docker run --rm "${IMAGE}" php -r 'exit(extension_loaded("Zend OPcache") ? 0 : 1);'

echo "[4/6] Starting web runtime"
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

echo "[5/6] Checking HTTP/PHP response"
response="$(docker exec "${CONTAINER}" wget -q -O - http://127.0.0.1:8080/)"
[ "${response}" = "production-ok" ] || {
    echo "Smoke test failed: unexpected response '${response}'." >&2
    exit 1
}

echo "[6/6] Checking graceful shutdown"
docker stop -t 10 "${CONTAINER}" >/dev/null
state="$(docker inspect --format '{{.State.Status}}' "${CONTAINER}")"
[ "${state}" = "exited" ] || {
    docker logs "${CONTAINER}" >&2 || true
    echo "Smoke test failed: container did not stop cleanly (state: ${state})." >&2
    exit 1
}

echo "Smoke test passed for PHP ${PHP_VERSION}."
