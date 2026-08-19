FROM alpine:3.24

ARG VERSION=2.0.0-dev.1

LABEL org.opencontainers.image.title="Production" \
      org.opencontainers.image.description="Lightweight general-purpose PHP production runtime" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.authors="João Pinto <suport@joaopinto.pt>" \
      org.opencontainers.image.source="https://github.com/joaopinto14/Production" \
      org.opencontainers.image.licenses="MIT"

ENV PRODUCTION_VERSION="${VERSION}" \
    TIMEZONE="UTC" \
    DOCUMENT_ROOT="/var/www/html" \
    PHP_MEMORY_LIMIT="128M" \
    UPLOAD_MAX_SIZE="8M"

RUN apk add --no-cache \
        ca-certificates \
        nginx \
        supervisor \
        tzdata \
        php85 \
        php85-fpm \
        php85-ctype \
        php85-curl \
        php85-fileinfo \
        php85-mbstring \
        php85-openssl \
        php85-pdo \
        php85-session \
        php85-tokenizer \
        php85-xml \
    && addgroup -S www \
    && adduser -S -D -H -G www www \
    && mkdir -p \
        /var/www/html \
        /run/nginx \
        /run/php \
        /tmp/nginx/client_body \
        /tmp/nginx/proxy \
        /tmp/nginx/fastcgi \
        /etc/supervisor/conf.d \
    && chown -R www:www /var/www/html /run/nginx /run/php /tmp/nginx \
    && rm -f /etc/nginx/http.d/default.conf \
    && ln -sf /usr/bin/php85 /usr/local/bin/php

COPY php/settings.ini /etc/php85/conf.d/50-production.ini
COPY php/php-fpm.conf /etc/php85/php-fpm.conf
COPY php/www.conf /etc/php85/php-fpm.d/www.conf

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/default.conf.template /etc/nginx/http.d/default.conf.template

COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0755 /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
