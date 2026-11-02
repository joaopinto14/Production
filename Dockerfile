# syntax=docker/dockerfile:1

# Keep this literal reference so Dependabot can propose digest updates.
FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

ARG VERSION=2.0.4
ARG PHP_VERSION=8.5
ARG VARIANT=generic
ARG VCS_REF=unknown
ARG WWW_UID=10001
ARG WWW_GID=10001

LABEL org.opencontainers.image.title="Production" \
      org.opencontainers.image.description="Lightweight PHP production runtime with optional Laravel variant" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.authors="João Pinto <geral@joaopinto.pt>" \
      org.opencontainers.image.vendor="João Pinto" \
      org.opencontainers.image.url="https://github.com/joaopinto14/Production" \
      org.opencontainers.image.documentation="https://github.com/joaopinto14/Production#readme" \
      org.opencontainers.image.source="https://github.com/joaopinto14/Production" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="docker.io/library/alpine:3.24" \
      io.joaopinto.production.php-version="${PHP_VERSION}" \
      io.joaopinto.production.variant="${VARIANT}" \
      io.joaopinto.production.runtime-user="www" \
      io.joaopinto.production.runtime-uid="${WWW_UID}" \
      io.joaopinto.production.runtime-gid="${WWW_GID}" \
      io.joaopinto.production.runtime-port="8080"

ENV PRODUCTION_VERSION="${VERSION}" \
    PRODUCTION_PHP_VERSION="${PHP_VERSION}" \
    PRODUCTION_VARIANT="${VARIANT}" \
    TIMEZONE="UTC" \
    TZ="UTC" \
    PHP_MEMORY_LIMIT="128M" \
    UPLOAD_MAX_SIZE="8M" \
    PHPRC="/etc/php-active" \
    PHP_INI_SCAN_DIR="/etc/php-active/conf.d:/etc/production/php/conf.d:/run/production/php/conf.d" \
    HOME="/tmp"

RUN set -eux; \
    case "${PHP_VERSION}" in \
        8.3) PHP_SLOT=83 ;; \
        8.4) PHP_SLOT=84 ;; \
        8.5) PHP_SLOT=85 ;; \
        *) echo "Unsupported PHP version: ${PHP_VERSION}. Supported: 8.3, 8.4, 8.5." >&2; exit 1 ;; \
    esac; \
    case "${VARIANT}" in \
        generic|laravel) ;; \
        *) echo "Unsupported variant: ${VARIANT}. Supported: generic, laravel." >&2; exit 1 ;; \
    esac; \
    PHP_PACKAGES=" \
        php${PHP_SLOT} \
        php${PHP_SLOT}-fpm \
        php${PHP_SLOT}-ctype \
        php${PHP_SLOT}-curl \
        php${PHP_SLOT}-fileinfo \
        php${PHP_SLOT}-mbstring \
        php${PHP_SLOT}-openssl \
        php${PHP_SLOT}-pdo \
        php${PHP_SLOT}-phar \
        php${PHP_SLOT}-session \
        php${PHP_SLOT}-tokenizer \
        php${PHP_SLOT}-xml \
    "; \
    if [ "${PHP_SLOT}" != "85" ]; then \
        PHP_PACKAGES="${PHP_PACKAGES} php${PHP_SLOT}-opcache"; \
    fi; \
    if [ "${VARIANT}" = "laravel" ]; then \
        PHP_PACKAGES="${PHP_PACKAGES} \
            php${PHP_SLOT}-bcmath \
            php${PHP_SLOT}-dom \
            php${PHP_SLOT}-intl \
            php${PHP_SLOT}-pcntl \
            php${PHP_SLOT}-pdo_mysql \
            php${PHP_SLOT}-pdo_pgsql \
            php${PHP_SLOT}-pdo_sqlite \
            php${PHP_SLOT}-pecl-redis \
            php${PHP_SLOT}-zip \
        "; \
    fi; \
    apk upgrade --no-cache; \
    apk add --no-cache \
        ca-certificates \
        nginx \
        tini \
        tzdata \
        ${PHP_PACKAGES}; \
    addgroup -S -g "${WWW_GID}" www; \
    adduser -S -D -H -u "${WWW_UID}" -G www www; \
    mkdir -p \
        /usr/local/bin \
        /usr/local/sbin \
        /var/www/html \
        /etc/production/php/conf.d \
        /etc/production/php/php-fpm.d \
        /run/production/nginx/http.d \
        /run/production/nginx/client_body \
        /run/production/nginx/proxy \
        /run/production/nginx/fastcgi \
        /run/production/nginx/uwsgi \
        /run/production/nginx/scgi \
        /run/production/php/conf.d; \
    ln -s "/etc/php${PHP_SLOT}" /etc/php-active; \
    ln -s "/usr/bin/php${PHP_SLOT}" /usr/local/bin/php; \
    ln -s "/usr/sbin/php-fpm${PHP_SLOT}" /usr/local/sbin/php-fpm; \
    chown -R www:www /var/www/html /run/production; \
    rm -f /etc/nginx/http.d/default.conf

COPY php/settings.ini /etc/production/php/conf.d/50-production.ini
COPY php/php-fpm.conf /etc/production/php/php-fpm.conf
COPY php/www.conf /etc/production/php/php-fpm.d/www.conf

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/default.conf.template /etc/nginx/default.conf.template
COPY nginx/laravel.conf.template /etc/nginx/laravel.conf.template

COPY entrypoint/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY entrypoint/runtime.sh /usr/local/bin/production-runtime

RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/production-runtime

WORKDIR /var/www/html

USER www

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -T 2 -O /dev/null http://127.0.0.1:8080/readyz || exit 1

STOPSIGNAL SIGTERM

# Keep an actual init in front of web AND CLI commands. Subreaper mode also
# handles an outer Docker --init without losing adopted grandchildren.
# Forward to the direct child only: group forwarding would bypass web draining.
ENTRYPOINT ["/sbin/tini", "-s", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/production-runtime"]
