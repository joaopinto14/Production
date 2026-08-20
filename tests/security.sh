#!/bin/sh
set -eu

. ./tests/lib.sh

section "Hardened runtime security tests"

CONTAINERS=""
DIRS=""
cleanup() {
    for c in ${CONTAINERS}; do remove_container "${c}"; done
    for d in ${DIRS}; do rm -rf "${d}"; done
}
trap cleanup EXIT INT TERM

run_security_test() {
    variant="$1"
    image="$(image_for "${variant}" 8.5)"
    ensure_image "${image}"
    container="production-security-${variant}-$$"
    app_dir="$(mktemp -d)"
    CONTAINERS="${CONTAINERS} ${container}"
    DIRS="${DIRS} ${app_dir}"

    uid="$(docker run --rm --entrypoint /usr/bin/id "${image}" -u)"
    gid="$(docker run --rm --entrypoint /usr/bin/id "${image}" -g)"

    if [ "${variant}" = "laravel" ]; then
        mkdir -p "${app_dir}/public" "${app_dir}/storage" "${app_dir}/bootstrap/cache"
        chmod 0755 "${app_dir}" "${app_dir}/public" "${app_dir}/storage" "${app_dir}/bootstrap" "${app_dir}/bootstrap/cache"
        target="${app_dir}/public/index.php"
        expected='security-laravel-ok'
        cat > "${target}" <<'EOF_PHP'
<?php
file_put_contents('/var/www/html/storage/security-probe', 'storage-ok');
file_put_contents('/var/www/html/bootstrap/cache/security-probe', 'cache-ok');
echo 'security-laravel-ok';
EOF_PHP
    else
        chmod 0755 "${app_dir}"
        target="${app_dir}/index.php"
        expected='security-generic-ok'
        printf '<?php echo %s;\n' "'${expected}'" > "${target}"
    fi

    chmod 0644 "${target}"

    if [ "${variant}" = "laravel" ]; then
        docker run -d \
            --name "${container}" \
            --read-only \
            --cap-drop ALL \
            --security-opt no-new-privileges:true \
            --pids-limit 64 \
            --tmpfs "/run/production:rw,nosuid,nodev,noexec,size=16m,mode=0755,uid=${uid},gid=${gid}" \
            --tmpfs "/tmp:rw,nosuid,nodev,noexec,size=16m,mode=1777" \
            --tmpfs "/var/www/html/storage:rw,nosuid,nodev,noexec,size=16m,mode=0770,uid=${uid},gid=${gid}" \
            --tmpfs "/var/www/html/bootstrap/cache:rw,nosuid,nodev,noexec,size=8m,mode=0770,uid=${uid},gid=${gid}" \
            -v "${app_dir}:/var/www/html:ro" \
            "${image}" >/dev/null
    else
        docker run -d \
            --name "${container}" \
            --read-only \
            --cap-drop ALL \
            --security-opt no-new-privileges:true \
            --pids-limit 64 \
            --tmpfs "/run/production:rw,nosuid,nodev,noexec,size=16m,mode=0755,uid=${uid},gid=${gid}" \
            --tmpfs "/tmp:rw,nosuid,nodev,noexec,size=16m,mode=1777" \
            -v "${app_dir}:/var/www/html:ro" \
            "${image}" >/dev/null
    fi

    wait_healthy "${container}"
    assert_eq "${expected}" "$(http_body "${container}" /)" "${variant} hardened response"
    if [ "${variant}" = "laravel" ]; then
        assert_eq 'storage-ok' "$(docker exec "${container}" cat /var/www/html/storage/security-probe)" "Laravel storage writable mount"
        assert_eq 'cache-ok' "$(docker exec "${container}" cat /var/www/html/bootstrap/cache/security-probe)" "Laravel bootstrap/cache writable mount"
    fi

    log "Checking no-new-privileges and zero effective capabilities (${variant})"
    no_new_privs="$(docker exec "${container}" sh -c "awk '/^NoNewPrivs:/ {print \$2}' /proc/1/status")"
    cap_eff="$(docker exec "${container}" sh -c "awk '/^CapEff:/ {print \$2}' /proc/1/status")"
    assert_eq '1' "${no_new_privs}" "NoNewPrivs flag"
    assert_eq '0000000000000000' "${cap_eff}" "effective capabilities"

    log "Checking read-only root with explicitly writable tmpfs surfaces (${variant})"
    docker exec "${container}" sh -c 'touch /run/production/security-write-test /tmp/security-write-test'
    if docker exec "${container}" sh -c 'touch /etc/production-should-not-write' >/dev/null 2>&1; then
        fail "${variant} container unexpectedly wrote to /etc."
    fi

    readonly="$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' "${container}")"
    capdrop="$(docker inspect --format '{{json .HostConfig.CapDrop}}' "${container}")"
    security_opts="$(docker inspect --format '{{json .HostConfig.SecurityOpt}}' "${container}")"
    assert_eq 'true' "${readonly}" "read-only root flag"
    assert_contains "${capdrop}" 'ALL' "cap-drop contract"
    pids_limit="$(docker inspect --format '{{.HostConfig.PidsLimit}}' "${container}")"
    assert_contains "${security_opts}" 'no-new-privileges:true' "no-new-privileges contract"
    assert_eq '64' "${pids_limit}" "pids-limit contract"

    docker stop -t 10 "${container}" >/dev/null
    assert_eq '0' "$(docker inspect --format '{{.State.ExitCode}}' "${container}")" "hardened graceful shutdown"
}

run_security_test generic
run_security_test laravel

printf '%s\n' 'Hardened runtime security tests passed.'
