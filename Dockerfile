FROM alpine

LABEL maintainer="João Pinto [suport@joaopinto.pt]"

# Install necessary packages
RUN apk update && apk add --no-cache php83 php83-fpm nginx supervisor tzdata && rm -rf /var/cache/apk/*

# PHP-FPM Configuration
COPY php/settings.ini /etc/php83/conf.d/
RUN sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php83/php.ini
RUN sed -i 's/user = nobody/user = www/' /etc/php83/php-fpm.d/www.conf
RUN sed -i 's/group = nobody/group = www/' /etc/php83/php-fpm.d/www.conf
RUN sed -i 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/' /etc/php83/php-fpm.d/www.conf
RUN sed -i 's/;listen.owner = nobody/listen.owner = www/' /etc/php83/php-fpm.d/www.conf
RUN sed -i 's/;listen.group = www/listen.group = www/' /etc/php83/php-fpm.d/www.conf
RUN sed -i 's/;listen.mode = 0660/listen.mode = 0660/' /etc/php83/php-fpm.d/www.conf

# Nginx Configuration
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

# Add new user
RUN adduser -D -g 'www' www

# Expose web server port and set healthcheck
EXPOSE 80
HEALTHCHECK --interval=60s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://localhost
WORKDIR /var/www/html
CMD ["entrypoint.sh"]