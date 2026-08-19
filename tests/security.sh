#!/bin/sh
set -eu

VERSION="${VERSION:-2.0.0-dev.6}"
PHP_VERSION="${PHP_VERSION:-8.5}"

cleanup() {
    docker rm -f production-security-generic production-security-laravel >/dev/null 2>&1 || true
    [ -z "${GENERIC_DIR:-}" ] || rm -rf "${GENERIC_DIR}"
    [ -z "${LARAVEL_DIR:-}" ] || rm -rf "${LARAVEL_DIR}"
}
trap cleanup EXIT INT TERM

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

run_security_test() {
    variant="$1"
    image="$2"
    container="$3"
    app_dir="$4"
    expected="$5"

    uid="$(docker run --rm --entrypoint /usr/bin/id "${image}" -u)"
    gid="$(docker run --rm --entrypoint /usr/bin/id "${image}" -g)"

    docker run -d \
        --name "${container}" \
        --read-only \
        --security-opt no-new-privileges:true \
        --tmpfs "/run/production:rw,nosuid,nodev,noexec,size=16m,mode=0755,uid=${uid},gid=${gid}" \
        --tmpfs "/tmp:rw,nosuid,nodev,noexec,size=16m,mode=1777" \
        -v "${app_dir}:/var/www/html:ro" \
        "${image}" >/dev/null

    wait_healthy "${container}"
    response="$(docker exec "${container}" wget -q -O - http://127.0.0.1:8080/)"
    [ "${response}" = "${expected}" ] || {
        docker logs "${container}" >&2 || true
        echo "Unexpected ${variant} response: ${response}" >&2
        exit 1
    }

    docker stop -t 10 "${container}" >/dev/null
}

GENERIC_IMAGE="production:${VERSION}-php${PHP_VERSION}"
LARAVEL_IMAGE="production:${VERSION}-laravel-php${PHP_VERSION}"

for image in "${GENERIC_IMAGE}" "${LARAVEL_IMAGE}"; do
    docker image inspect "${image}" >/dev/null 2>&1 || {
        echo "Required image not found: ${image}. Run ./tests/smoke-all.sh first." >&2
        exit 1
    }
done

GENERIC_DIR="$(mktemp -d)"
chmod 0755 "${GENERIC_DIR}"
cat > "${GENERIC_DIR}/index.php" <<'EOF_PHP'
<?php echo 'security-generic-ok';
EOF_PHP
chmod 0644 "${GENERIC_DIR}/index.php"

LARAVEL_DIR="$(mktemp -d)"
mkdir -p "${LARAVEL_DIR}/public" "${LARAVEL_DIR}/storage" "${LARAVEL_DIR}/bootstrap/cache"
chmod 0755 "${LARAVEL_DIR}" "${LARAVEL_DIR}/public" "${LARAVEL_DIR}/storage" "${LARAVEL_DIR}/bootstrap" "${LARAVEL_DIR}/bootstrap/cache"
cat > "${LARAVEL_DIR}/public/index.php" <<'EOF_PHP'
<?php echo 'security-laravel-ok';
EOF_PHP
chmod 0644 "${LARAVEL_DIR}/public/index.php"

echo "[1/2] Testing generic image with read-only root filesystem"
run_security_test generic "${GENERIC_IMAGE}" production-security-generic "${GENERIC_DIR}" security-generic-ok

echo "[2/2] Testing Laravel image with read-only root filesystem"
run_security_test laravel "${LARAVEL_IMAGE}" production-security-laravel "${LARAVEL_DIR}" security-laravel-ok

echo "Security tests passed."
