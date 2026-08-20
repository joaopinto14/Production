#!/bin/sh
set -eu

. ./tests/lib.sh

PHP_VERSION="${PHP_VERSION:-8.5}"
VARIANT="${VARIANT:-generic}"
IMAGE="${IMAGE:-$(image_for "${VARIANT}" "${PHP_VERSION}")}"
CONTAINER="production-smoke-${VARIANT}-${PHP_VERSION}-$$"
APP_DIR="$(mktemp -d)"
chmod 0755 "${APP_DIR}"

cleanup() {
    remove_container "${CONTAINER}"
    rm -rf "${APP_DIR}"
}
trap cleanup EXIT INT TERM

ensure_image "${IMAGE}"

if [ "${VARIANT}" = "laravel" ]; then
    mkdir -p "${APP_DIR}/public" "${APP_DIR}/storage" "${APP_DIR}/bootstrap/cache"
    chmod 0755 "${APP_DIR}/public" "${APP_DIR}/storage" "${APP_DIR}/bootstrap" "${APP_DIR}/bootstrap/cache"
    cat > "${APP_DIR}/public/index.php" <<'EOF_PHP'
<?php header('Content-Type: text/plain'); echo 'laravel-runtime-ok';
EOF_PHP
    cat > "${APP_DIR}/public/direct.php" <<'EOF_PHP'
<?php echo 'must-not-run';
EOF_PHP
    cat > "${APP_DIR}/index.php" <<'EOF_PHP'
<?php echo 'wrong-document-root';
EOF_PHP
    chmod 0644 "${APP_DIR}/public/index.php" "${APP_DIR}/public/direct.php" "${APP_DIR}/index.php"
    expected='laravel-runtime-ok'
else
    cat > "${APP_DIR}/index.php" <<'EOF_PHP'
<?php header('Content-Type: text/plain'); echo 'production-ok';
EOF_PHP
    chmod 0644 "${APP_DIR}/index.php"
    expected='production-ok'
fi

log "Starting ${IMAGE}"
docker run -d \
    --name "${CONTAINER}" \
    --security-opt no-new-privileges:true \
    -v "${APP_DIR}:/var/www/html:ro" \
    "${IMAGE}" >/dev/null

wait_healthy "${CONTAINER}"

assert_eq "${expected}" "$(http_body "${CONTAINER}" /)" "root HTTP response"
assert_eq "ok" "$(http_body "${CONTAINER}" /healthz)" "health endpoint"

if [ "${VARIANT}" = "laravel" ]; then
    assert_eq "404" "$(http_status "${CONTAINER}" /direct.php)" "Laravel direct PHP execution must be blocked"
fi

docker exec "${CONTAINER}" nginx -t >/dev/null 2>&1 || fail "nginx -t failed in ${IMAGE}"
docker exec "${CONTAINER}" php-fpm -tt --fpm-config /etc/production/php/php-fpm.conf >/dev/null 2>&1 || fail "php-fpm config test failed in ${IMAGE}"

log "Checking graceful shutdown"
docker stop -t 10 "${CONTAINER}" >/dev/null
assert_eq "exited" "$(docker inspect --format '{{.State.Status}}' "${CONTAINER}")" "container stop state"
assert_eq "0" "$(docker inspect --format '{{.State.ExitCode}}' "${CONTAINER}")" "graceful shutdown exit code"

printf 'Smoke test passed: %s / PHP %s\n' "${VARIANT}" "${PHP_VERSION}"
