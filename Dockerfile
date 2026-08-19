FROM alpine:3.24

ARG VERSION=2.0.0-dev.4
ARG PHP_VERSION=8.5

LABEL org.opencontainers.image.title="Production" \
      org.opencontainers.image.description="Lightweight general-purpose PHP production runtime" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.authors="João Pinto <suport@joaopinto.pt>" \
      org.opencontainers.image.source="https://github.com/joaopinto14/Production" \
      org.opencontainers.image.licenses="MIT" \
      io.joaopinto.production.php-version="${PHP_VERSION}"

ENV PRODUCTION_VERSION="${VERSION}" \
    PRODUCTION_PHP_VERSION="${PHP_VERSION}" \
    TIMEZONE="UTC" \
    TZ="UTC" \
    DOCUMENT_ROOT="/var/www/html" \
    PHP_MEMORY_LIMIT="128M" \
    UPLOAD_MAX_SIZE="8M" \
    PHPRC="/etc/php-active" \
    PHP_INI_SCAN_DIR="/etc/php-active/conf.d:/etc/production/php/conf.d:/run/production/php/conf.d" \
    HOME="/tmp"

RUN set -eux; \
    PHP_SLOT="$(printf '%s' "${PHP_VERSION}" | tr -d '.')"; \
    case "${PHP_SLOT}" in \
        83|84|85) ;; \
        *) echo "Unsupported PHP version: ${PHP_VERSION}. Supported: 8.3, 8.4, 8.5." >&2; exit 1 ;; \
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
        php${PHP_SLOT}-session \
        php${PHP_SLOT}-tokenizer \
        php${PHP_SLOT}-xml \
    "; \
    if [ "${PHP_SLOT}" != "85" ]; then \
        PHP_PACKAGES="${PHP_PACKAGES} php${PHP_SLOT}-opcache"; \
    fi; \
    apk add --no-cache \
        ca-certificates \
        nginx \
        tzdata \
        ${PHP_PACKAGES}; \
    addgroup -S www; \
    adduser -S -D -H -G www www; \
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

COPY entrypoint/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY entrypoint/runtime.sh /usr/local/bin/production-runtime

RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/production-runtime

WORKDIR /var/www/html

USER www

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/production-runtime"]
