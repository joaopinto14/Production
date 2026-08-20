#!/bin/sh
set -eu

. ./tests/lib.sh

section "Concurrent PHP-FPM workload tests"

run_load_test() {
    variant="$1"
    image="$(image_for "${variant}" 8.5)"
    ensure_image "${image}"

    container="production-load-${variant}-$$"
    app_dir="$(mktemp -d)"

    if [ "${variant}" = "laravel" ]; then
        mkdir -p "${app_dir}/public" "${app_dir}/storage" "${app_dir}/bootstrap/cache"
        chmod 0755 "${app_dir}" "${app_dir}/public" "${app_dir}/storage" "${app_dir}/bootstrap" "${app_dir}/bootstrap/cache"
        target="${app_dir}/public/index.php"
        path='/load'
    else
        chmod 0755 "${app_dir}"
        target="${app_dir}/index.php"
        path='/'
    fi

    cat > "${target}" <<'EOF_PHP'
<?php
usleep(25000);
header('Content-Type: text/plain');
echo 'load-ok';
EOF_PHP
    chmod 0644 "${target}"

    docker run -d --name "${container}" -v "${app_dir}:/var/www/html:ro" "${image}" >/dev/null
    wait_healthy "${container}"

    log "${variant}: 50 concurrent dynamic requests"
    docker exec "${container}" sh -c "
        set -u
        rm -f /tmp/load-failed
        i=0
        while [ \"\${i}\" -lt 50 ]; do
            (
                response=\"\$(wget -q -O - 'http://127.0.0.1:8080${path}' 2>/dev/null || true)\"
                [ \"\${response}\" = 'load-ok' ] || touch /tmp/load-failed
            ) &
            i=\$((i + 1))
        done
        wait
        [ ! -e /tmp/load-failed ]
    " || {
        docker logs "${container}" >&2 || true
        remove_container "${container}"
        rm -rf "${app_dir}"
        fail "Concurrent requests failed for ${variant}."
    }

    assert_eq 'healthy' "$(docker inspect --format '{{.State.Health.Status}}' "${container}")" "health after concurrency test"
    assert_eq 'load-ok' "$(http_body "${container}" "${path}")" "runtime response after concurrency test"

    remove_container "${container}"
    rm -rf "${app_dir}"
}

run_load_test generic
run_load_test laravel

printf '%s\n' 'Concurrent workload tests passed.'
