#!/bin/sh
set -eu

VERSION="${VERSION:-2.0.0-dev.6}"
PHP_VERSION="${PHP_VERSION:-8.5}"
VARIANT="${VARIANT:-generic}"

case "${PHP_VERSION}" in
    8.3|8.4|8.5) ;;
    *)
        echo "Unsupported PHP_VERSION '${PHP_VERSION}'. Use 8.3, 8.4 or 8.5." >&2
        exit 1
        ;;
esac

case "${VARIANT}" in
    generic)
        IMAGE="${IMAGE:-production:${VERSION}-php${PHP_VERSION}}"
        ;;
    laravel)
        IMAGE="${IMAGE:-production:${VERSION}-laravel-php${PHP_VERSION}}"
        ;;
    *)
        echo "Unsupported VARIANT '${VARIANT}'. Use generic or laravel." >&2
        exit 1
        ;;
esac

CONTAINER="production-smoke-$$"
APP_DIR="$(mktemp -d)"
chmod 0755 "${APP_DIR}"

cleanup() {
    docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
    rm -rf "${APP_DIR}"
}
trap cleanup EXIT INT TERM

if [ "${VARIANT}" = "laravel" ]; then
    mkdir -p "${APP_DIR}/public" "${APP_DIR}/storage" "${APP_DIR}/bootstrap/cache"
    chmod 0755 "${APP_DIR}/public" "${APP_DIR}/storage" "${APP_DIR}/bootstrap" "${APP_DIR}/bootstrap/cache"

    cat > "${APP_DIR}/public/index.php" <<'EOF_PHP'
<?php
header('Content-Type: text/plain');
echo 'laravel-runtime-ok';
EOF_PHP
    cat > "${APP_DIR}/public/direct.php" <<'EOF_PHP'
<?php echo 'must-not-run';
EOF_PHP
    cat > "${APP_DIR}/index.php" <<'EOF_PHP'
<?php echo 'wrong-document-root';
EOF_PHP
    chmod 0644 "${APP_DIR}/public/index.php" "${APP_DIR}/public/direct.php" "${APP_DIR}/index.php"
else
    cat > "${APP_DIR}/index.php" <<'EOF_PHP'
<?php
header('Content-Type: text/plain');
echo 'production-ok';
EOF_PHP
    chmod 0644 "${APP_DIR}/index.php"
fi

echo "[1/8] Building ${IMAGE}"
docker build \
    --build-arg VERSION="${VERSION}" \
    --build-arg PHP_VERSION="${PHP_VERSION}" \
    --build-arg VARIANT="${VARIANT}" \
    -t "${IMAGE}" .

echo "[2/8] Checking PHP ${PHP_VERSION}, OCI metadata and non-root runtime"
actual_php_version="$(docker run --rm "${IMAGE}" php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')"
[ "${actual_php_version}" = "${PHP_VERSION}" ] || {
    echo "Smoke test failed: expected PHP ${PHP_VERSION}, got ${actual_php_version}." >&2
    exit 1
}
actual_variant="$(docker image inspect "${IMAGE}" --format '{{index .Config.Labels "io.joaopinto.production.variant"}}')"
[ "${actual_variant}" = "${VARIANT}" ] || {
    echo "Smoke test failed: expected variant ${VARIANT}, got ${actual_variant}." >&2
    exit 1
}
actual_version="$(docker image inspect "${IMAGE}" --format '{{index .Config.Labels "org.opencontainers.image.version"}}')"
[ "${actual_version}" = "${VERSION}" ] || {
    echo "Smoke test failed: expected OCI version ${VERSION}, got ${actual_version}." >&2
    exit 1
}
actual_source="$(docker image inspect "${IMAGE}" --format '{{index .Config.Labels "org.opencontainers.image.source"}}')"
[ "${actual_source}" = "https://github.com/joaopinto14/Production" ] || {
    echo "Smoke test failed: unexpected OCI source ${actual_source}." >&2
    exit 1
}
runtime_uid="$(docker run --rm --entrypoint /usr/bin/id "${IMAGE}" -u)"
[ "${runtime_uid}" != "0" ] || {
    echo "Smoke test failed: image runs as root." >&2
    exit 1
}

echo "[3/8] Checking slim runtime"
docker run --rm --entrypoint /bin/sh "${IMAGE}" -c '
    ! command -v supervisord >/dev/null 2>&1
    ! command -v python3 >/dev/null 2>&1
    test -x /usr/local/bin/production-runtime
'

echo "[4/8] Checking OPcache and variant extensions"
docker run --rm "${IMAGE}" php -r 'exit(extension_loaded("Zend OPcache") ? 0 : 1);'

if [ "${VARIANT}" = "laravel" ]; then
    docker run --rm "${IMAGE}" php -r '
        $required = [
            "ctype", "curl", "dom", "fileinfo", "filter", "hash", "mbstring",
            "openssl", "pcre", "PDO", "session", "tokenizer", "xml",
            "bcmath", "intl", "pcntl", "pdo_mysql", "pdo_pgsql", "pdo_sqlite",
            "redis", "zip"
        ];
        $missing = array_values(array_filter($required, fn ($ext) => !extension_loaded($ext)));
        if ($missing) {
            fwrite(STDERR, "Missing extensions: ".implode(", ", $missing).PHP_EOL);
            exit(1);
        }
    '
fi

echo "[5/8] Starting web runtime"
docker run -d \
    --name "${CONTAINER}" \
    --security-opt no-new-privileges:true \
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

echo "[6/8] Checking HTTP/PHP response"
response="$(docker exec "${CONTAINER}" wget -q -O - http://127.0.0.1:8080/)"
if [ "${VARIANT}" = "laravel" ]; then
    [ "${response}" = "laravel-runtime-ok" ] || {
        echo "Smoke test failed: unexpected Laravel response '${response}'." >&2
        exit 1
    }
else
    [ "${response}" = "production-ok" ] || {
        echo "Smoke test failed: unexpected response '${response}'." >&2
        exit 1
    }
fi

echo "[7/8] Checking variant web contract"
if [ "${VARIANT}" = "laravel" ]; then
    direct_status="$(docker exec "${CONTAINER}" wget -S -O /dev/null http://127.0.0.1:8080/direct.php 2>&1 | awk '/HTTP\// {print $2; exit}' || true)"
    [ "${direct_status}" = "404" ] || {
        docker logs "${CONTAINER}" >&2 || true
        echo "Smoke test failed: Laravel direct PHP file returned HTTP ${direct_status:-unknown}, expected 404." >&2
        exit 1
    }
fi

echo "[8/8] Checking graceful shutdown"
docker stop -t 10 "${CONTAINER}" >/dev/null
state="$(docker inspect --format '{{.State.Status}}' "${CONTAINER}")"
[ "${state}" = "exited" ] || {
    docker logs "${CONTAINER}" >&2 || true
    echo "Smoke test failed: container did not stop cleanly (state: ${state})." >&2
    exit 1
}

size="$(docker image inspect "${IMAGE}" --format='{{.Size}}')"
echo "Smoke test passed for ${VARIANT} / PHP ${PHP_VERSION}."
echo "Image size: ${size} bytes"
