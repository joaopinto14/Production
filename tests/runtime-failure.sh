#!/bin/sh
set -eu

. ./tests/lib.sh

section "Runtime crash and signal handling"

IMAGE="$(image_for generic 8.5)"
ensure_image "${IMAGE}"
APP_DIR="$(mktemp -d)"
chmod 0755 "${APP_DIR}"
cat > "${APP_DIR}/index.php" <<'EOF_PHP'
<?php echo 'runtime-ok';
EOF_PHP
chmod 0644 "${APP_DIR}/index.php"

CONTAINERS=""
cleanup() {
    for c in ${CONTAINERS}; do remove_container "${c}"; done
    rm -rf "${APP_DIR}"
}
trap cleanup EXIT INT TERM

LAST_CONTAINER=""
start_container() {
    suffix="$1"
    LAST_CONTAINER="production-runtime-${suffix}-$$"
    CONTAINERS="${CONTAINERS} ${LAST_CONTAINER}"
    docker run -d --name "${LAST_CONTAINER}" -v "${APP_DIR}:/var/www/html:ro" "${IMAGE}" >/dev/null
    wait_healthy "${LAST_CONTAINER}"
}

assert_exit_code() {
    container="$1"
    expected="$2"
    wait_exited "${container}" 20
    actual="$(docker inspect --format '{{.State.ExitCode}}' "${container}")"
    [ "${actual}" = "${expected}" ] || {
        docker logs "${container}" >&2 || true
        fail "${container} exited with ${actual}, expected ${expected}."
    }
}

log "Killing Nginx: PID 1 must fail the container and terminate PHP-FPM"
start_container nginx-crash
container="${LAST_CONTAINER}"
docker exec "${container}" sh -c 'kill -KILL "$(cat /run/production/nginx/nginx.pid)"'
assert_exit_code "${container}" 1

log "Killing PHP-FPM: PID 1 must fail the container and terminate Nginx"
start_container fpm-crash
container="${LAST_CONTAINER}"
docker exec "${container}" sh -c 'kill -KILL "$(cat /run/production/php/php-fpm.pid)"'
assert_exit_code "${container}" 1

for signal in TERM INT QUIT; do
    log "Sending ${signal} to PID 1: graceful exit must return 0"
    start_container "signal-${signal}"
    container="${LAST_CONTAINER}"
    docker kill --signal="${signal}" "${container}" >/dev/null
    assert_exit_code "${container}" 0
done

printf '%s\n' 'Runtime crash and signal tests passed.'
