#!/bin/sh

# Define default values for environment variables if they are not set
PROJECT_PATH=${PROJECT_PATH:-/var/www/html}
MEMORY_LIMIT=${MEMORY_LIMIT:-128M}
UPLOAD_MAX=${UPLOAD_MAX:-100M}

# Replace the PROJECT_PATH placeholder with the actual path
sed -i "s|PROJECT_PATH|$PROJECT_PATH|" /etc/nginx/http.d/default.conf
# Replace the CLIENT_MAX_BODY_SIZE placeholder with the actual value
sed -i "s|UPLOAD_MAX|$UPLOAD_MAX|" /etc/nginx/http.d/default.conf

# Replace the MEMORY_LIMIT placeholder with the actual value
sed -i "s|MEMORY_LIMIT|$MEMORY_LIMIT|" /etc/php83/conf.d/production.ini
sed -i "s|MEMORY_LIMIT|$MEMORY_LIMIT|" /etc/php83/php-fpm.d/www.conf

# Replace the POST_MAX_FILESIZE and POST_MAX_SIZE placeholders with the actual value
sed -i "s|UPLOAD_MAX|$UPLOAD_MAX|" /etc/php83/conf.d/production.ini

# Set the correct permissions for the project directory
chown -R nginx:www-data /var/www/html

# Start PHP-FPM and Nginx
php-fpm83 & nginx -g "daemon off;"