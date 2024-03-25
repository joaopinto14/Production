FROM alpine:3.19

LABEL maintainer="João Pinto [suport@joaopinto.pt]"

# Install PHP and Nginx
RUN apk update && apk add --no-cache \
    php83 \
    php83-fpm \
    nginx=1.24.0-r15 && \
    rm -rf /var/cache/apk/*

# Copy PHP configuration file
COPY php/settings.ini /etc/php83/conf.d/settings.ini
COPY php/www.conf /etc/php83/php-fpm.d/www.conf

# Copy Nginx configuration file and custom startup script
COPY nginx/default.conf /etc/nginx/http.d/default.conf
COPY entrypoint/entrypoint.sh /usr/local/bin/entrypoint.sh

# Make the startup script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Move PHP and PHP-FPM binaries to the default path
RUN mv /usr/bin/php83 /usr/bin/php && \
    mv /usr/sbin/php-fpm83 /usr/sbin/php-fpm

# Expose web server port and set healthcheck
EXPOSE 80
HEALTHCHECK --interval=60s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://localhost

# Set the working directory
WORKDIR /var/www/html

CMD ["entrypoint.sh"]