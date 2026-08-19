#!/bin/sh
set -eu

TIMEZONE="${TIMEZONE:-UTC}"
DOCUMENT_ROOT="${DOCUMENT_ROOT:-/var/www/html}"
PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-128M}"
UPLOAD_MAX_SIZE="${UPLOAD_MAX_SIZE:-8M}"
SUPERVISOR_CONF="${SUPERVISOR_CONF:-}"

NGINX_TEMPLATE="/etc/nginx/http.d/default.conf.template"
NGINX_CONF="/etc/nginx/http.d/default.conf"
PHP_RUNTIME_CONF="/etc/php85/conf.d/99-production-runtime.ini"
SUPERVISOR_CONF_DIR="/etc/supervisor/conf.d"

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

    ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
    printf '%s\n' "${TIMEZONE}" > /etc/timezone
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

configure_supervisor_extension() {
    [ -n "${SUPERVISOR_CONF}" ] || return 0
    [ -f "${SUPERVISOR_CONF}" ] || fail "Supervisor configuration not found: ${SUPERVISOR_CONF}"

    cp -f "${SUPERVISOR_CONF}" "${SUPERVISOR_CONF_DIR}/custom.conf"
}

configure_timezone
configure_php

case "${1:-}" in
    /usr/bin/supervisord|supervisord)
        configure_nginx
        configure_supervisor_extension
        log "Version ${PRODUCTION_VERSION:-unknown}"
        log "PHP $(php -r 'echo PHP_VERSION;')"
        log "Document root: ${DOCUMENT_ROOT}"
        ;;
esac

exec "$@"
