#!/bin/sh

# Replace the PROJECT_PATH placeholder with the actual path
sed -i "s|PROJECT_PATH|$PROJECT_PATH|" /etc/nginx/http.d/default.conf

# Start PHP-FPM and Nginx
php-fpm82 & nginx -g "daemon off;"