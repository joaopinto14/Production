#!/bin/sh
set -eu

. ./tests/lib.sh

section "Laravel service shortcuts, CLI health and init"
APP_DIR="$(mktemp -d)"
CONTAINERS=""
cleanup() {
    for item in ${CONTAINERS}; do remove_container "${item}"; done
    rm -rf "${APP_DIR}"
}
trap cleanup EXIT INT TERM
chmod 0755 "${APP_DIR}"

cat > "${APP_DIR}/artisan" <<'PHP'
<?php
declare(strict_types=1);
$report = [
    'args' => array_slice($argv, 1),
    'pid' => getmypid(),
    'init' => trim(file_get_contents('/proc/1/comm')),
    'memory' => ini_get('memory_limit'),
    'timezone' => date_default_timezone_get(),
];
file_put_contents('/tmp/production-command.json', json_encode($report, JSON_THROW_ON_ERROR));
if (($argv[1] ?? '') === 'fail') { exit(23); }
if (!in_array($argv[1] ?? '', ['schedule:work', 'queue:work'], true)) {
    echo json_encode($report, JSON_THROW_ON_ERROR);
    exit(0);
}
// Exercise adopted descendants while the actual service process remains alive.
$argv = ['/orphan-burst.php', '5', '40'];
require '/orphan-burst.php';
PHP
chmod 0644 "${APP_DIR}/artisan"

for php_version in ${PHP_VERSIONS:-8.3 8.4 8.5}; do
    image="$(image_for laravel "${php_version}")"
    ensure_image "${image}"
    for service_mode in scheduler queue; do
        container="production-mode-${service_mode}-${php_version}-$$"
        CONTAINERS="${CONTAINERS} ${container}"
        log "${service_mode} on PHP ${php_version}: init, health, orphans and signals"
        docker run -d --name "${container}" --network none \
            --read-only --cap-drop ALL --security-opt no-new-privileges:true \
            --pids-limit 512 --health-interval 1s --health-start-period 0s \
            --tmpfs /tmp:rw,nosuid,nodev,noexec,size=32m,mode=1777 \
            --tmpfs /run/production:rw,nosuid,nodev,noexec,size=16m,mode=0755,uid=10001,gid=10001 \
            -e DOCUMENT_ROOT=/does/not/exist -e TIMEZONE=Europe/Lisbon -e PHP_MEMORY_LIMIT=192M \
            -v "${APP_DIR}:/var/www/html:ro" \
            -v "$(pwd)/tests/orphan-burst.php:/orphan-burst.php:ro" \
            "${image}" "${service_mode}" --verbose 'literal value;$(touch /tmp/unexpected-command)' >/dev/null
        wait_healthy "${container}" 30
        assert_eq tini "$(docker exec "${container}" cat /proc/1/comm)" "service init"
        assert_eq cli "$(docker exec "${container}" cat /run/production/mode)" "service health mode"
        docker exec "${container}" php -r '
            $report = json_decode(file_get_contents("/tmp/production-command.json"), true, flags: JSON_THROW_ON_ERROR);
            $expected = $argv[1] === "scheduler" ? "schedule:work" : "queue:work";
            $args = [$expected, "--verbose", "literal value;" . chr(36) . "(touch /tmp/unexpected-command)"];
            if ($report["args"] !== $args || $report["init"] !== "tini" || $report["pid"] === 1
                || $report["memory"] !== "192M" || $report["timezone"] !== "Europe/Lisbon") {
                fwrite(STDERR, json_encode($report)); exit(1);
            }
            if (file_exists("/tmp/unexpected-command")) { exit(1); }
        ' "${service_mode}"
        attempt=0
        until docker exec "${container}" test -f /tmp/production-orphan-report.json; do
            attempt=$((attempt + 1))
            [ "${attempt}" -lt 30 ] || fail "Service orphan workload did not complete"
            sleep 1
        done
        docker exec -i "${container}" sh -s < tests/zombie-check.sh
        processes="$(docker top "${container}" -eo pid,comm)"
        assert_not_contains "${processes}" nginx "CLI shortcut started Nginx"
        assert_not_contains "${processes}" php-fpm "CLI shortcut started PHP-FPM"
        log "Checking CLI health rejects a missing main process"
        service_pid="$(docker exec "${container}" cat /run/production/command.pid)"
        docker exec "${container}" sh -c 'printf "%s\n" 99999999 > /run/production/command.pid'
        if docker exec "${container}" production-healthcheck; then
            fail "CLI health accepted a missing process"
        fi
        docker exec "${container}" sh -c 'printf "%s\n" "$1" > /run/production/command.pid' sh "${service_pid}"
        docker exec "${container}" production-healthcheck
        docker stop -t 5 "${container}" >/dev/null
        assert_eq 143 "$(docker inspect --format '{{.State.ExitCode}}' "${container}")" "CLI signal forwarding"
        remove_container "${container}"
    done
    log "Checking Artisan shortcut, explicit launcher and exit status on PHP ${php_version}"
    result="$(docker run --rm --network none --entrypoint production -v "${APP_DIR}:/var/www/html:ro" \
        "${image}" artisan about --only=environment)"
    assert_contains "${result}" '"args":["about","--only=environment"]' "Artisan arguments"
    assert_contains "${result}" '"init":"tini"' "explicit launcher lost init"
    code=0
    docker run --rm --network none -v "${APP_DIR}:/var/www/html:ro" "${image}" artisan fail || code=$?
    assert_eq 23 "${code}" "Artisan exit status"
    log "Preserving full PHP/Artisan commands"
    result="$(docker run --rm --network none -v "${APP_DIR}:/var/www/html:ro" "${image}" php artisan about)"
    assert_contains "${result}" '"args":["about"]' "full Artisan command"
    output="$(docker run --rm --network none "${image}" scheduler 2>&1)" && fail "Missing Artisan app unexpectedly succeeded"
    assert_contains "${output}" 'Artisan not found' "missing app error"
done
image="$(image_for generic 8.5)"
ensure_image "${image}"
output="$(docker run --rm --network none "${image}" scheduler 2>&1)" && fail "Generic image accepted Laravel shortcut"
assert_contains "${output}" 'requires the Laravel image' "generic shortcut error"
printf '%s\n' 'Service shortcut, CLI health, orphan reaping and signal tests passed.'
