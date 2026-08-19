#!/bin/sh
set -eu

TIMEZONE="${TIMEZONE:-UTC}"
DOCUMENT_ROOT="${DOCUMENT_ROOT:-/var/www/html}"
PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-128M}"
UPLOAD_MAX_SIZE="${UPLOAD_MAX_SIZE:-8M}"

NGINX_TEMPLATE="/etc/nginx/default.conf.template"
NGINX_CONF="/run/production/nginx/http.d/default.conf"
PHP_RUNTIME_CONF="/run/production/php/conf.d/99-production-runtime.ini"

log() {
    printf '[Production] %s\n' "$*"
}

fail() {
    printf '[Production] ERROR: %s\n' "$*" >&2
    exit 1
}

escape_sed() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

configure_timezone() {
    [ -f "/usr/share/zoneinfo/${TIMEZONE}" ] || fail "Invalid timezone: ${TIMEZONE}"
    export TZ="${TIMEZONE}"
}

configure_php() {
    cat > "${PHP_RUNTIME_CONF}" <<EOF_PHP
memory_limit = ${PHP_MEMORY_LIMIT}
upload_max_filesize = ${UPLOAD_MAX_SIZE}
post_max_size = ${UPLOAD_MAX_SIZE}
date.timezone = ${TIMEZONE}
EOF_PHP
}

configure_nginx() {
    [ -f "${NGINX_TEMPLATE}" ] || fail "Nginx template not found: ${NGINX_TEMPLATE}"
    [ -d "${DOCUMENT_ROOT}" ] || fail "DOCUMENT_ROOT does not exist: ${DOCUMENT_ROOT}"

    document_root_escaped="$(escape_sed "${DOCUMENT_ROOT}")"
    upload_max_size_escaped="$(escape_sed "${UPLOAD_MAX_SIZE}")"

    sed \
        -e "s|__DOCUMENT_ROOT__|${document_root_escaped}|g" \
        -e "s|__UPLOAD_MAX_SIZE__|${upload_max_size_escaped}|g" \
        "${NGINX_TEMPLATE}" > "${NGINX_CONF}"
}

configure_timezone
configure_php

case "${1:-}" in
    /usr/local/bin/production-runtime|production-runtime)
        configure_nginx
        log "Version ${PRODUCTION_VERSION:-unknown}"
        log "PHP $(php -r 'echo PHP_VERSION;')"
        log "Runtime user: $(id -u):$(id -g)"
        log "Document root: ${DOCUMENT_ROOT}"
        log "Listening on: 8080"
        ;;
esac

exec "$@"
