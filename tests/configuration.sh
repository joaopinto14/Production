#!/bin/sh
set -eu

. ./tests/lib.sh

section "Runtime configuration matrix"

IMAGE="$(image_for generic 8.5)"
ensure_image "${IMAGE}"
CONTAINER="production-config-$$"
APP_DIR="$(mktemp -d)"
mkdir -p "${APP_DIR}/custom"
chmod 0755 "${APP_DIR}" "${APP_DIR}/custom"
cat > "${APP_DIR}/custom/index.php" <<'EOF_PHP'
<?php
echo implode('|', [
    ini_get('memory_limit'),
    ini_get('upload_max_filesize'),
    ini_get('post_max_size'),
    ini_get('date.timezone'),
]);
EOF_PHP
chmod 0644 "${APP_DIR}/custom/index.php"

cleanup() {
    remove_container "${CONTAINER}"
    rm -rf "${APP_DIR}"
}
trap cleanup EXIT INT TERM

log "Checking environment overrides"
docker run -d \
    --name "${CONTAINER}" \
    -e TIMEZONE=Europe/Lisbon \
    -e PHP_MEMORY_LIMIT=192M \
    -e UPLOAD_MAX_SIZE=2M \
    -e DOCUMENT_ROOT=/var/www/html/custom \
    -v "${APP_DIR}:/var/www/html:ro" \
    "${IMAGE}" >/dev/null
wait_healthy "${CONTAINER}"

assert_eq '192M|2M|2M|Europe/Lisbon' "$(http_body "${CONTAINER}" /)" "PHP runtime override contract"

php_runtime="$(docker exec "${CONTAINER}" cat /run/production/php/conf.d/99-production-runtime.ini)"
assert_contains "${php_runtime}" 'memory_limit = 192M' "generated memory_limit"
assert_contains "${php_runtime}" 'upload_max_filesize = 2M' "generated upload_max_filesize"
assert_contains "${php_runtime}" 'post_max_size = 2M' "generated post_max_size"
assert_contains "${php_runtime}" 'date.timezone = Europe/Lisbon' "generated timezone"

nginx_dump="$(docker exec "${CONTAINER}" nginx -T 2>&1)"
assert_contains "${nginx_dump}" 'root /var/www/html/custom;' "custom document root"
assert_contains "${nginx_dump}" 'client_max_body_size 2M;' "Nginx upload limit"

remove_container "${CONTAINER}"

log "Rejecting invalid timezones"
TMP_LOG="$(mktemp)"
if docker run --rm -e TIMEZONE=Invalid/Timezone "${IMAGE}" php -v >"${TMP_LOG}" 2>&1; then
    rm -f "${TMP_LOG}"
    fail "Invalid timezone unexpectedly succeeded."
fi
assert_contains "$(cat "${TMP_LOG}")" 'Invalid timezone: Invalid/Timezone' "invalid timezone error"
rm -f "${TMP_LOG}"

log "Rejecting missing document roots for web runtime"
TMP_LOG="$(mktemp)"
if docker run --rm -e DOCUMENT_ROOT=/does/not/exist "${IMAGE}" >"${TMP_LOG}" 2>&1; then
    rm -f "${TMP_LOG}"
    fail "Missing DOCUMENT_ROOT unexpectedly succeeded."
fi
assert_contains "$(cat "${TMP_LOG}")" 'DOCUMENT_ROOT does not exist: /does/not/exist' "missing document root error"
rm -f "${TMP_LOG}"

log "Allowing CLI commands without a web document root"
docker run --rm -e DOCUMENT_ROOT=/does/not/exist "${IMAGE}" php -r 'echo "cli-ok";' | grep -qx 'cli-ok' || fail "CLI command incorrectly depends on DOCUMENT_ROOT."

printf '%s\n' 'Runtime configuration tests passed.'
