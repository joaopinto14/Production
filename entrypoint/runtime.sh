#!/bin/sh
set -u

PHP_FPM_PID=""
NGINX_PID=""
SHUTTING_DOWN=0

log() {
    printf '[Production] %s\n' "$*"
}

stop_child() {
    signal="$1"
    pid="$2"

    [ -n "${pid}" ] || return 0
    kill -0 "${pid}" 2>/dev/null || return 0
    kill -"${signal}" "${pid}" 2>/dev/null || true
}

wait_child() {
    pid="$1"
    [ -n "${pid}" ] || return 0
    wait "${pid}" 2>/dev/null || true
}

shutdown() {
    [ "${SHUTTING_DOWN}" -eq 0 ] || return 0
    SHUTTING_DOWN=1

    trap - TERM INT QUIT
    log "Stopping Nginx and PHP-FPM"

    # QUIT requests a graceful shutdown from both Nginx and PHP-FPM.
    stop_child QUIT "${NGINX_PID}"
    stop_child QUIT "${PHP_FPM_PID}"

    wait_child "${NGINX_PID}"
    wait_child "${PHP_FPM_PID}"
}

trap 'shutdown; exit 0' TERM INT QUIT

/usr/local/sbin/php-fpm \
    --nodaemonize \
    --fpm-config /etc/production/php/php-fpm.conf &
PHP_FPM_PID=$!

/usr/sbin/nginx \
    -e /dev/stderr \
    -g 'daemon off;' &
NGINX_PID=$!

log "PHP-FPM PID: ${PHP_FPM_PID}"
log "Nginx PID: ${NGINX_PID}"

# BusyBox ash is deliberately used instead of adding a process supervisor.
# If either service exits unexpectedly, stop the other and fail the container.
while :; do
    if ! kill -0 "${PHP_FPM_PID}" 2>/dev/null; then
        wait "${PHP_FPM_PID}" 2>/dev/null
        status=$?
        log "PHP-FPM exited unexpectedly (status ${status})"
        stop_child QUIT "${NGINX_PID}"
        wait_child "${NGINX_PID}"
        exit 1
    fi

    if ! kill -0 "${NGINX_PID}" 2>/dev/null; then
        wait "${NGINX_PID}" 2>/dev/null
        status=$?
        log "Nginx exited unexpectedly (status ${status})"
        stop_child QUIT "${PHP_FPM_PID}"
        wait_child "${PHP_FPM_PID}"
        exit 1
    fi

    sleep 1 &
    wait $! || true
done
