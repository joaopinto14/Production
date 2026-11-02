#!/bin/sh
set -u

PHP_FPM_PID=""
NGINX_PID=""
SHUTTING_DOWN=0
SHUTDOWN_TIMEOUT="${SHUTDOWN_TIMEOUT:-30}"
case "${SHUTDOWN_TIMEOUT}" in
    [1-9]|[1-9][0-9]|[12][0-9][0-9]|300) ;;
    *) printf '%s\n' 'SHUTDOWN_TIMEOUT must be an integer from 1 to 300' >&2; exit 1 ;;
esac

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

drain_child() {
    pid="$1"
    [ -n "${pid}" ] || return 0
    while kill -0 "${pid}" 2>/dev/null; do
        if [ "$(date +%s)" -ge "${SHUTDOWN_DEADLINE}" ]; then
            log "Shutdown deadline reached; killing PID ${pid}"
            stop_child KILL "${pid}"
            SHUTDOWN_FORCED=1
            break
        fi
        sleep 1
    done
    wait "${pid}" 2>/dev/null || true
}

shutdown() {
    [ "${SHUTTING_DOWN}" -eq 0 ] || return 0
    SHUTTING_DOWN=1

    trap '' TERM INT QUIT
    SHUTDOWN_DEADLINE="$(expr "$(date +%s)" + "${SHUTDOWN_TIMEOUT}")"
    SHUTDOWN_FORCED=0
    log "Draining Nginx before stopping PHP-FPM (deadline ${SHUTDOWN_TIMEOUT}s)"

    # FPM must remain available until Nginx has completed active requests.
    stop_child QUIT "${NGINX_PID}"
    drain_child "${NGINX_PID}"
    stop_child QUIT "${PHP_FPM_PID}"
    drain_child "${PHP_FPM_PID}"
    return "${SHUTDOWN_FORCED}"
}

trap 'shutdown; exit $?' TERM INT QUIT

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

# Tini owns PID 1 and reaps adopted orphans in both web and CLI mode.
# This BusyBox shell only supervises the two web services beneath it.
# If either service exits unexpectedly, stop the other and fail the container.
while :; do
    if ! kill -0 "${PHP_FPM_PID}" 2>/dev/null; then
        wait "${PHP_FPM_PID}" 2>/dev/null
        status=$?
        log "PHP-FPM exited unexpectedly (status ${status})"
        shutdown
        exit 1
    fi

    if ! kill -0 "${NGINX_PID}" 2>/dev/null; then
        wait "${NGINX_PID}" 2>/dev/null
        status=$?
        log "Nginx exited unexpectedly (status ${status})"
        shutdown
        exit 1
    fi

    sleep 1 &
    wait $! || true
done
