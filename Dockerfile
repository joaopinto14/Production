FROM alpine:3.19

LABEL maintainer="João Pinto [suport@joaopinto.pt]"

# Install PHP and Nginx
RUN apk update && apk add --no-cache \
    php83 \
    php83-fpm \
    php83-ctype \
    php83-curl \
    php83-dom \
    php83-fileinfo \
    php83-mbstring \
    php83-openssl \
    php83-pdo \
    php83-pdo_mysql \
    php83-mysqli \
    php83-session \
    php83-tokenizer \
    php83-xml \
    nginx=1.24.0-r15 && \
    rm -rf /var/cache/apk/*

# Copy PHP configuration file
COPY php/production.ini /etc/php83/conf.d/production.ini
COPY php/www.conf /etc/php83/php-fpm.d/www.conf

# Copy Nginx configuration file and custom startup script
COPY nginx/default.conf /etc/nginx/http.d/default.conf
COPY entrypoint/entrypoint.sh /usr/local/bin/entrypoint.sh

# Make the startup script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose web server port and set healthcheck
EXPOSE 80
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://localhost

CMD ["entrypoint.sh"]