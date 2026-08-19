#!/bin/sh
set -eu

VERSION="${VERSION:-2.0.0-dev.6}"
PHP_VERSION="${PHP_VERSION:-8.5}"
IMAGE="${IMAGE:-production:${VERSION}-php${PHP_VERSION}}"
APP_DIR="$(mktemp -d)"
chmod 0755 "${APP_DIR}"

cat > "${APP_DIR}/index.php" <<'EOF_PHP'
<?php
header('Content-Type: text/plain');
echo 'runtime-failure-test';
EOF_PHP
chmod 0644 "${APP_DIR}/index.php"

cleanup() {
    docker rm -f production-crash-nginx production-crash-fpm >/dev/null 2>&1 || true
    rm -rf "${APP_DIR}"
}
trap cleanup EXIT INT TERM

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "Building ${IMAGE}"
    docker build \
        --build-arg VERSION="${VERSION}" \
        --build-arg PHP_VERSION="${PHP_VERSION}" \
        --build-arg VARIANT=generic \
        -t "${IMAGE}" .
fi

wait_healthy() {
    container="$1"
    attempt=0
    while [ "${attempt}" -lt 20 ]; do
        status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${container}" 2>/dev/null || true)"
        [ "${status}" = "healthy" ] && return 0
        attempt=$((attempt + 1))
        sleep 1
    done
    docker logs "${container}" >&2 || true
    echo "Container ${container} did not become healthy." >&2
    return 1
}

wait_stopped_with_code_1() {
    container="$1"
    attempt=0
    while [ "${attempt}" -lt 15 ]; do
        state="$(docker inspect --format '{{.State.Status}}' "${container}" 2>/dev/null || true)"
        [ "${state}" = "exited" ] && break
        attempt=$((attempt + 1))
        sleep 1
    done

    state="$(docker inspect --format '{{.State.Status}}' "${container}")"
    code="$(docker inspect --format '{{.State.ExitCode}}' "${container}")"
    [ "${state}" = "exited" ] && [ "${code}" = "1" ] || {
        docker logs "${container}" >&2 || true
        echo "Expected ${container} to exit with code 1, got state=${state} code=${code}." >&2
        exit 1
    }
}

echo "[1/2] Killing Nginx and checking fail-fast behaviour"
docker run -d --name production-crash-nginx -v "${APP_DIR}:/var/www/html:ro" "${IMAGE}" >/dev/null
wait_healthy production-crash-nginx
docker exec production-crash-nginx sh -c 'kill -KILL "$(cat /run/production/nginx/nginx.pid)"'
wait_stopped_with_code_1 production-crash-nginx

echo "[2/2] Killing PHP-FPM and checking fail-fast behaviour"
docker run -d --name production-crash-fpm -v "${APP_DIR}:/var/www/html:ro" "${IMAGE}" >/dev/null
wait_healthy production-crash-fpm
docker exec production-crash-fpm sh -c 'kill -KILL "$(cat /run/production/php/php-fpm.pid)"'
wait_stopped_with_code_1 production-crash-fpm

echo "Runtime failure tests passed."
