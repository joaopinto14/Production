#!/bin/sh

# Define default values for environment variables if they are not set
PHP_EXTENSIONS=${PHP_EXTENSIONS:-}
PROJECT_PATH=${PROJECT_PATH:-/var/www/html}
MEMORY_LIMIT=${MEMORY_LIMIT:-128M}
UPLOAD_MAX=${UPLOAD_MAX:-8M}

# Define file paths
NGINX_CONF="/etc/nginx/http.d/default.conf"
PHP_INI="/etc/php83/conf.d/settings.ini"
PHP_FPM_CONF="/etc/php83/php-fpm.d/www.conf"

# Check if the project directory exists and is not empty
if [ ! -d "${PROJECT_PATH}" ] || [ -z "$(ls -A "${PROJECT_PATH}")" ]; then
  echo "You need to put your project in the ${PROJECT_PATH} directory."
  exit 1
fi

# Function to check and install PHP extensions
check_and_install_extension() {
  installed_extensions=$(php -m)
    
  for extension in ${PHP_EXTENSIONS}; do
    # Check if there is any uninstalled extension
    if ! echo "${installed_extensions}" | grep -q "${extension}"; then
      if [ -z "${extensions_to_install}" ]; then
        extensions_to_install="${extension}"
      else
        extensions_to_install="${extensions_to_install} ${extension}"
      fi
    fi
  done

  # Install uninstalled PHP extensions
  if [ -n "${extensions_to_install}" ]; then
    echo "Installing PHP extensions: ${extensions_to_install}..."
    for extension in ${extensions_to_install}; do
      apk add -q --no-cache php83-"${extension}" > /dev/null 2>&1 || { echo "Failed to install PHP extension: ${extension}."; exit 1; }
    done
    rm -rf /var/cache/apk/*
    echo "PHP extensions installed successfully."
  fi
}

# Replace placeholders with actual values in configuration files
sed -i "s|PROJECT_PATH|${PROJECT_PATH}|;s|UPLOAD_MAX|${UPLOAD_MAX}|" ${NGINX_CONF} || { echo "Failed to replace placeholders in ${NGINX_CONF}."; exit 1; }
sed -i "s|MEMORY_LIMIT|${MEMORY_LIMIT}|;s|UPLOAD_MAX|${UPLOAD_MAX}|" ${PHP_INI} || { echo "Failed to replace placeholders in ${PHP_INI}."; exit 1; }
sed -i "s|MEMORY_LIMIT|${MEMORY_LIMIT}|" ${PHP_FPM_CONF} || { echo "Failed to replace placeholders in ${PHP_FPM_CONF}."; exit 1; }

# Install the required PHP extensions
if [ -n "${PHP_EXTENSIONS}" ]; then
  check_and_install_extension
fi

# Create directory for the sock file
mkdir -p /var/run/php || { echo "Failed to create directory '/var/run/php'."; exit 1; }

# Set the correct permissions for the project directory and the sock file directory
chown -R nginx:www-data /var/www/html /var/run/php || { echo "Failed to set permissions for '/var/www/html' and '/var/run/php'."; exit 1; }

# Start PHP-FPM and Nginx
php-fpm -D && nginx -g "daemon off;"