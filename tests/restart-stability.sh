#!/bin/sh
set -eu

. ./tests/lib.sh

section "Restart stability and zombie-process tests"

CONTAINERS=""
DIRS=""
cleanup() {
    for c in ${CONTAINERS}; do remove_container "${c}"; done
    for d in ${DIRS}; do rm -rf "${d}"; done
}
trap cleanup EXIT INT TERM

run_restart_test() {
    variant="$1"
    image="$(image_for "${variant}" 8.5)"
    ensure_image "${image}"
    app_dir="$(mktemp -d)"
    container="production-restart-${variant}-$$"
    DIRS="${DIRS} ${app_dir}"
    CONTAINERS="${CONTAINERS} ${container}"
    chmod 0755 "${app_dir}"

    if [ "${variant}" = 'laravel' ]; then
        mkdir -p "${app_dir}/public" "${app_dir}/storage" "${app_dir}/bootstrap/cache"
        chmod 0755 "${app_dir}/public" "${app_dir}/storage" "${app_dir}/bootstrap" "${app_dir}/bootstrap/cache"
        printf '<?php echo "restart-ok";\n' > "${app_dir}/public/index.php"
        target="${app_dir}/public/index.php"
    else
        printf '<?php echo "restart-ok";\n' > "${app_dir}/index.php"
        target="${app_dir}/index.php"
    fi
    chmod 0644 "${target}"

    docker run -d --name "${container}" -v "${app_dir}:/var/www/html:ro" "${image}" >/dev/null
    wait_healthy "${container}"

    i=1
    while [ "${i}" -le 5 ]; do
        log "${variant}: restart cycle ${i}/5"
        docker restart -t 10 "${container}" >/dev/null
        wait_healthy "${container}"
        assert_eq 'restart-ok' "$(http_body "${container}" /)" "response after restart ${i} (${variant})"
        docker exec -i "${container}" sh -s < tests/zombie-check.sh \
            || fail "Persistent zombie detected after restart ${i} (${variant})."
        i=$((i + 1))
    done

    if [ "${variant}" = laravel ]; then
        log "Checking the detector against a deliberately unreaped child"
        docker exec "${container}" php -r '
            $pid = pcntl_fork();
            if ($pid === 0) { exit(0); }
            if ($pid < 0) { exit(1); }
            sleep(6);
            pcntl_waitpid($pid, $status);
        ' >/dev/null 2>&1 &
        fixture_pid=$!
        sleep 1
        if docker exec -i "${container}" sh -s < tests/zombie-check.sh; then
            wait "${fixture_pid}" || true
            fail "Zombie detector accepted a persistent unreaped child."
        fi
        wait "${fixture_pid}"
    fi

    docker stop -t 10 "${container}" >/dev/null
    assert_eq '0' "$(docker inspect --format '{{.State.ExitCode}}' "${container}")" "restart stability shutdown (${variant})"
}

run_restart_test generic
run_restart_test laravel

printf '%s\n' 'Restart stability and zombie-process tests passed.'
