#!/bin/sh
set -eu

. ./tests/lib.sh

section "Deep HTTP/Nginx contract tests"

GENERIC_IMAGE="$(image_for generic 8.5)"
LARAVEL_IMAGE="$(image_for laravel 8.5)"
ensure_image "${GENERIC_IMAGE}"
ensure_image "${LARAVEL_IMAGE}"

CONTAINERS=""
DIRS=""
cleanup() {
    for c in ${CONTAINERS}; do remove_container "${c}"; done
    for d in ${DIRS}; do rm -rf "${d}"; done
}
trap cleanup EXIT INT TERM

make_common_files() {
    root="$1"
    mkdir -p "${root}/.well-known"
    printf '%s' 'static-ok' > "${root}/static.txt"
    printf '%s' 'secret' > "${root}/.env"
    printf '%s' 'acme-ok' > "${root}/.well-known/acme.txt"
    chmod 0644 "${root}/static.txt" "${root}/.env" "${root}/.well-known/acme.txt"
    chmod 0755 "${root}/.well-known"
}

GENERIC_DIR="$(mktemp -d)"; DIRS="${DIRS} ${GENERIC_DIR}"; chmod 0755 "${GENERIC_DIR}"
make_common_files "${GENERIC_DIR}"
cat > "${GENERIC_DIR}/index.php" <<'EOF_PHP'
<?php
header('Content-Type: text/plain');
echo 'front|' . ($_SERVER['REQUEST_URI'] ?? '') . '|' . ($_SERVER['REQUEST_METHOD'] ?? '');
EOF_PHP
cat > "${GENERIC_DIR}/direct.php" <<'EOF_PHP'
<?php echo 'direct-ok';
EOF_PHP
chmod 0644 "${GENERIC_DIR}/index.php" "${GENERIC_DIR}/direct.php"

GENERIC="production-http-generic-$$"; CONTAINERS="${CONTAINERS} ${GENERIC}"
docker run -d --name "${GENERIC}" -e UPLOAD_MAX_SIZE=1K -v "${GENERIC_DIR}:/var/www/html:ro" "${GENERIC_IMAGE}" >/dev/null
wait_healthy "${GENERIC}"

assert_eq 'front|/|GET' "$(http_body "${GENERIC}" /)" "generic front controller"
assert_eq 'front|/route?x=1|GET' "$(http_body "${GENERIC}" '/route?x=1')" "generic fallback route"
assert_eq 'direct-ok' "$(http_body "${GENERIC}" /direct.php)" "generic direct PHP execution"
assert_eq 'static-ok' "$(http_body "${GENERIC}" /static.txt)" "generic static file"
assert_eq '403' "$(http_status "${GENERIC}" /.env)" "generic dotfile protection"
assert_eq 'acme-ok' "$(http_body "${GENERIC}" /.well-known/acme.txt)" "ACME well-known access"
assert_eq 'ok' "$(http_body "${GENERIC}" /healthz)" "generic health endpoint"

headers="$(http_headers "${GENERIC}" /)"
assert_contains "${headers}" 'X-Frame-Options: SAMEORIGIN' "X-Frame-Options header"
assert_contains "${headers}" 'X-Content-Type-Options: nosniff' "X-Content-Type-Options header"
assert_contains "${headers}" 'Referrer-Policy: strict-origin-when-cross-origin' "Referrer-Policy header"
assert_not_contains "${headers}" 'X-Powered-By:' "PHP version header leak"
assert_not_contains "${headers}" 'nginx/' "Nginx version leak"

log "Checking client_max_body_size at the HTTP layer"
post_status="$(docker exec "${GENERIC}" php -r '
    $ctx = stream_context_create(["http" => ["method" => "POST", "content" => str_repeat("x", 2048), "ignore_errors" => true]]);
    @file_get_contents("http://127.0.0.1:8080/", false, $ctx);
    echo $http_response_header[0] ?? "";
')"
assert_contains "${post_status}" '413' "oversized request must be rejected"

LARAVEL_DIR="$(mktemp -d)"; DIRS="${DIRS} ${LARAVEL_DIR}"
mkdir -p "${LARAVEL_DIR}/public" "${LARAVEL_DIR}/storage" "${LARAVEL_DIR}/bootstrap/cache"
chmod 0755 "${LARAVEL_DIR}" "${LARAVEL_DIR}/public" "${LARAVEL_DIR}/storage" "${LARAVEL_DIR}/bootstrap" "${LARAVEL_DIR}/bootstrap/cache"
make_common_files "${LARAVEL_DIR}/public"
cat > "${LARAVEL_DIR}/public/index.php" <<'EOF_PHP'
<?php
header('Content-Type: text/plain');
echo 'laravel-front|' . ($_SERVER['REQUEST_URI'] ?? '') . '|' . ($_SERVER['REQUEST_METHOD'] ?? '');
EOF_PHP
cat > "${LARAVEL_DIR}/public/direct.php" <<'EOF_PHP'
<?php echo 'must-not-run';
EOF_PHP
chmod 0644 "${LARAVEL_DIR}/public/index.php" "${LARAVEL_DIR}/public/direct.php"

LARAVEL="production-http-laravel-$$"; CONTAINERS="${CONTAINERS} ${LARAVEL}"
docker run -d --name "${LARAVEL}" -v "${LARAVEL_DIR}:/var/www/html:ro" "${LARAVEL_IMAGE}" >/dev/null
wait_healthy "${LARAVEL}"

assert_eq 'laravel-front|/|GET' "$(http_body "${LARAVEL}" /)" "Laravel front controller"
assert_eq 'laravel-front|/users/42?active=1|GET' "$(http_body "${LARAVEL}" '/users/42?active=1')" "Laravel route fallback"
assert_eq '404' "$(http_status "${LARAVEL}" /direct.php)" "Laravel direct PHP protection"
assert_eq 'static-ok' "$(http_body "${LARAVEL}" /static.txt)" "Laravel static file"
assert_eq '403' "$(http_status "${LARAVEL}" /.env)" "Laravel dotfile protection"
assert_eq 'acme-ok' "$(http_body "${LARAVEL}" /.well-known/acme.txt)" "Laravel ACME well-known access"
assert_eq 'ok' "$(http_body "${LARAVEL}" /healthz)" "Laravel health endpoint"

headers="$(http_headers "${LARAVEL}" /)"
assert_contains "${headers}" 'X-Frame-Options: SAMEORIGIN' "Laravel X-Frame-Options"
assert_contains "${headers}" 'X-Content-Type-Options: nosniff' "Laravel X-Content-Type-Options"
assert_contains "${headers}" 'Referrer-Policy: strict-origin-when-cross-origin' "Laravel Referrer-Policy"
assert_not_contains "${headers}" 'X-Powered-By:' "Laravel PHP version header leak"
assert_not_contains "${headers}" 'nginx/' "Laravel Nginx version leak"

printf '%s\n' 'Deep HTTP/Nginx contract tests passed.'
