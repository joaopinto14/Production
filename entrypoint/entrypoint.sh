#!/bin/sh
set -eu

umask 027

TIMEZONE="${TIMEZONE:-UTC}"
PRODUCTION_VARIANT="${PRODUCTION_VARIANT:-generic}"
PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-128M}"
UPLOAD_MAX_SIZE="${UPLOAD_MAX_SIZE:-8M}"

case "${PRODUCTION_VARIANT}" in
    generic)
        DEFAULT_DOCUMENT_ROOT="/var/www/html"
        NGINX_TEMPLATE="/etc/nginx/default.conf.template"
        ;;
    laravel)
        DEFAULT_DOCUMENT_ROOT="/var/www/html/public"
        NGINX_TEMPLATE="/etc/nginx/laravel.conf.template"
        ;;
    *)
        printf '[Production] ERROR: Unsupported variant: %s\n' "${PRODUCTION_VARIANT}" >&2
        exit 1
        ;;
esac

DOCUMENT_ROOT="${DOCUMENT_ROOT:-${DEFAULT_DOCUMENT_ROOT}}"
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

prepare_runtime() {
    mkdir -p \
        /run/production/nginx/http.d \
        /run/production/nginx/client_body \
        /run/production/nginx/proxy \
        /run/production/nginx/fastcgi \
        /run/production/nginx/uwsgi \
        /run/production/nginx/scgi \
        /run/production/php/conf.d
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

prepare_runtime
configure_timezone
configure_php

case "${1:-}" in
    /usr/local/bin/production-runtime|production-runtime)
        configure_nginx
        log "Version ${PRODUCTION_VERSION:-unknown}"
        log "Variant ${PRODUCTION_VARIANT}"
        log "PHP $(php -r 'echo PHP_VERSION;')"
        log "Runtime user: $(id -u):$(id -g)"
        log "Document root: ${DOCUMENT_ROOT}"
        log "Listening on: 8080"
        ;;
esac

exec "$@"
