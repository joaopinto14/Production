#!/bin/sh
set -eu

. ./tests/lib.sh

section "Docker stdout/stderr logging contract"

IMAGE="$(image_for generic 8.5)"
ensure_image "${IMAGE}"
CONTAINER="production-logging-$$"
APP_DIR="$(mktemp -d)"
chmod 0755 "${APP_DIR}"
cat > "${APP_DIR}/index.php" <<'EOF_PHP'
<?php echo 'logging-ok';
EOF_PHP
cat > "${APP_DIR}/error.php" <<'EOF_PHP'
<?php error_log('production-log-probe'); echo 'error-log-ok';
EOF_PHP
chmod 0644 "${APP_DIR}/index.php" "${APP_DIR}/error.php"

cleanup() {
    remove_container "${CONTAINER}"
    rm -rf "${APP_DIR}"
}
trap cleanup EXIT INT TERM

docker run -d --name "${CONTAINER}" -v "${APP_DIR}:/var/www/html:ro" "${IMAGE}" >/dev/null
wait_healthy "${CONTAINER}"
assert_eq 'error-log-ok' "$(http_body "${CONTAINER}" /error.php)" "logging probe response"
sleep 1

logs="$(docker logs "${CONTAINER}" 2>&1)"
assert_contains "${logs}" 'production-log-probe' "PHP application log must reach Docker logs"
assert_contains "${logs}" '"request":"GET /error.php HTTP/1.1"' "Nginx access log must reach Docker logs"

json_line="$(printf '%s\n' "${logs}" | grep '"request":"GET /error.php HTTP/1.1"' | tail -n 1)"
[ -n "${json_line}" ] || fail "Could not find JSON access log line."
printf '%s' "${json_line}" | docker run --rm -i "${IMAGE}" php -r '
    $line = stream_get_contents(STDIN);
    $decoded = json_decode($line, true);
    if (!is_array($decoded) || ($decoded["status"] ?? null) !== 200) {
        fwrite(STDERR, "Invalid JSON access log: $line\n");
        exit(1);
    }
' || fail "Nginx access log is not valid JSON."

printf '%s\n' 'Logging contract tests passed.'
