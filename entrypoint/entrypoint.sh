#!/bin/sh

# Define default values for environment variables if they are not set
PHP_EXTENSIONS=${PHP_EXTENSIONS:-}
PROJECT_PATH=${PROJECT_PATH:-/var/www/html}
MEMORY_LIMIT=${MEMORY_LIMIT:-128M}
UPLOAD_MAX=${UPLOAD_MAX:-8M}

# Get the list of already installed extensions via "php -m" command
INSTALLED_EXTENSIONS=$(php -m | tr -d ' ' | sed 's/\[PHPModules\]//g' | sed 's/\[ZendModules\]//g')

# Install the required PHP extensions
if [ -n "${PHP_EXTENSIONS}" ]; then
  for i in ${PHP_EXTENSIONS}; do
    # Check if the extension is already installed
    if echo "${INSTALLED_EXTENSIONS}" | grep -q "${i}"; then
      echo "The PHP extension ${i} is already installed."
    else
      # Install the extension
      if apk add --no-cache php83-${i} > /dev/nu&1; then
        echo "The PHP extension ${i} has been installed successfully."
      else
        echo "The PHP extension ${i} could not be installed."
      fi
    fi
  done
fi

# Check if the /var/www/html directory is empty
if [ -z "$(ls -A /var/www/html)" ]; then
  echo "The directory 'var/www/html' is empty"
  exit 1
fi

# Replace the PROJECT_PATH placeholder with the actual path
sed -i "s|PROJECT_PATH|$PROJECT_PATH|" /etc/nginx/http.d/default.conf
# Replace the CLIENT_MAX_BODY_SIZE placeholder with the actual value
sed -i "s|UPLOAD_MAX|$UPLOAD_MAX|" /etc/nginx/http.d/default.conf

# Replace the MEMORY_LIMIT placeholder with the actual value
sed -i "s|MEMORY_LIMIT|$MEMORY_LIMIT|" /etc/php83/conf.d/settings.ini
sed -i "s|MEMORY_LIMIT|$MEMORY_LIMIT|" /etc/php83/php-fpm.d/www.conf

# Replace the POST_MAX_FILESIZE and POST_MAX_SIZE placeholders with the actual value
sed -i "s|UPLOAD_MAX|$UPLOAD_MAX|" /etc/php83/conf.d/settings.ini

# Create directory for the sock file
mkdir -p /var/run/php

# Set the correct permissions for the project directory
chown -R nginx:www-data /var/www/html /var/run/php

# Start PHP-FPM and Nginx
php-fpm & nginx -g "daemon off;"