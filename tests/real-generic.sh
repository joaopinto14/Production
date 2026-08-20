#!/bin/sh
set -eu

. ./tests/lib.sh

section "Real PHP application tests"

CONTAINERS=""
DIRS=""
cleanup() {
    for c in ${CONTAINERS}; do remove_container "${c}"; done
    for d in ${DIRS}; do rm -rf "${d}"; done
}
trap cleanup EXIT INT TERM

for php_version in 8.3 8.4 8.5; do
    image="$(image_for generic "${php_version}")"
    ensure_image "${image}"

    app_dir="$(mktemp -d)"
    container="production-real-generic-${php_version}-$$"
    DIRS="${DIRS} ${app_dir}"
    CONTAINERS="${CONTAINERS} ${container}"
    chmod 0755 "${app_dir}"

    cat > "${app_dir}/index.php" <<'PHP'
<?php
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
header('Content-Type: text/plain; charset=utf-8');

switch ($path) {
    case '/':
        echo 'generic-real-ok';
        break;

    case '/runtime':
        echo PHP_VERSION . '|' . PHP_SAPI . '|' . (extension_loaded('Zend OPcache') ? 'opcache' : 'no-opcache');
        break;

    case '/route/example':
        echo 'front-controller-ok';
        break;

    case '/post':
        echo ($_SERVER['REQUEST_METHOD'] ?? '') . '|' . ($_POST['value'] ?? '');
        break;

    case '/session-write':
        session_save_path('/tmp');
        session_id('production-rc-session');
        session_start();
        $_SESSION['value'] = 'session-ok';
        session_write_close();
        echo 'written';
        break;

    case '/session-read':
        session_save_path('/tmp');
        session_id('production-rc-session');
        session_start();
        echo $_SESSION['value'] ?? 'missing';
        session_write_close();
        break;

    case '/tmp-write':
        file_put_contents('/tmp/production-real-app', 'tmp-ok');
        echo file_get_contents('/tmp/production-real-app');
        break;

    case '/warning':
        trigger_error('production-real-warning', E_USER_WARNING);
        echo 'warning-hidden';
        break;

    default:
        http_response_code(404);
        echo 'not-found';
}
PHP
    printf 'static-real-ok\n' > "${app_dir}/asset.txt"
    chmod 0644 "${app_dir}/index.php" "${app_dir}/asset.txt"

    log "Starting real generic app on PHP ${php_version}"
    docker run -d \
        --name "${container}" \
        --security-opt no-new-privileges:true \
        -v "${app_dir}:/var/www/html:ro" \
        "${image}" >/dev/null

    wait_healthy "${container}"

    assert_eq 'generic-real-ok' "$(http_body "${container}" /)" "generic root response (${php_version})"
    runtime="$(http_body "${container}" /runtime)"
    assert_contains "${runtime}" "${php_version}." "runtime PHP version (${php_version})"
    assert_contains "${runtime}" 'fpm-fcgi' "runtime SAPI (${php_version})"
    assert_contains "${runtime}" 'opcache' "runtime OPcache (${php_version})"
    assert_eq 'front-controller-ok' "$(http_body "${container}" /route/example)" "front controller (${php_version})"
    assert_eq 'static-real-ok' "$(http_body "${container}" /asset.txt)" "static file (${php_version})"
    assert_eq 'tmp-ok' "$(http_body "${container}" /tmp-write)" "tmp write (${php_version})"
    assert_eq 'written' "$(http_body "${container}" /session-write)" "session write (${php_version})"
    assert_eq 'session-ok' "$(http_body "${container}" /session-read)" "session persistence (${php_version})"

    post_result="$(docker exec "${container}" wget -q -O - --post-data='value=post-ok' http://127.0.0.1:8080/post)"
    assert_eq 'POST|post-ok' "${post_result}" "POST parsing (${php_version})"

    assert_eq 'warning-hidden' "$(http_body "${container}" /warning)" "display_errors must remain off (${php_version})"
    logs="$(docker logs "${container}" 2>&1)"
    assert_contains "${logs}" 'production-real-warning' "PHP warning must reach container logs (${php_version})"

    docker stop -t 10 "${container}" >/dev/null
    assert_eq '0' "$(docker inspect --format '{{.State.ExitCode}}' "${container}")" "generic real app shutdown (${php_version})"
done

printf '%s\n' 'Real PHP application tests passed on PHP 8.3, 8.4 and 8.5.'
