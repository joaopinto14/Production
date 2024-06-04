FROM alpine

LABEL maintainer="João Pinto [suport@joaopinto.pt]"

# Install necessary packages
RUN apk update && apk add --no-cache php83 php83-fpm nginx supervisor tzdata && rm -rf /var/cache/apk/*

# Copy PHP and Nginx configuration files
COPY php/settings.ini /etc/php83/conf.d/
COPY php/www.conf /etc/php83/php-fpm.d/
COPY nginx/default.conf /etc/nginx/http.d/
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Rename PHP and PHP-FPM binaries
RUN mv /usr/bin/php83 /usr/bin/php && mv /usr/sbin/php-fpm83 /usr/sbin/php-fpm

# Copy entrypoint script and make it executable
COPY entrypoint/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy Supervisor configuration file and create necessary directories
COPY supervisor/supervisord.conf /etc/supervisor/
RUN mkdir -p /etc/supervisor/conf /var/log/supervisor

# Expose port, set healthcheck, working directory and command
EXPOSE 80
HEALTHCHECK --interval=60s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://localhost
WORKDIR /var/www/html
CMD ["entrypoint.sh"]