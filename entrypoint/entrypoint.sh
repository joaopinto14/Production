#!/bin/ash

# Define default values for environment variables if they are not set
PHP_EXTENSIONS=${PHP_EXTENSIONS:-}
TIMEZONE=${TIMEZONE:-UTC}
INDEX_PATH=${INDEX_PATH:-/var/www/html}
MEMORY_LIMIT=${MEMORY_LIMIT:-128M}
UPLOAD_MAX_SIZE=${UPLOAD_MAX_SIZE:-8M}
SUPERVISOR_CONF=${SUPERVISOR_CONF:-}

# Define file paths
NGINX_CONF="/etc/nginx/nginx.conf"
NGINX_VIRTUAL_HOST_CONF="/etc/nginx/http.d/default.conf"
PHP_INI="/etc/php83/conf.d/settings.ini"
PHP_FPM_CONF="/etc/php83/php-fpm.d/www.conf"

# Check if the file index.php exists in the INDEX_PATH directory
if [ ! -f "${INDEX_PATH}/index.php" ]; then
  echo "The path specified in INDEX_PATH does not contain the 'index.php' file."
  exit 1
fi

# Function to check and install PHP extensions
check_and_install_extension() {
  installed_extensions=$(php -m | tr '[:upper:]' '[:lower:]')
  extensions_to_install=""

  for extension in ${PHP_EXTENSIONS}; do
    # Convert extension name to lowercase
    extension=$(echo "${extension}" | tr '[:upper:]' '[:lower:]')
    # Check if there is any uninstalled extension
    if ! echo "${installed_extensions}" | grep -wq "${extension}"; then
      extensions_to_install="${extensions_to_install} ${extension}"
    fi
  done

  # Install uninstalled PHP extensions
  if [ -n "${extensions_to_install}" ]; then
    echo "Installing PHP extensions:${extensions_to_install}..."
    for extension in ${extensions_to_install}; do
      apk add -q --no-cache php83-"${extension}" > /dev/null 2>&1
    done
    # Check if extensions were installed successfully
    installed_extensions=$(php -m | tr '[:upper:]' '[:lower:]')
    for extension in ${extensions_to_install}; do
      if ! echo "${installed_extensions}" | grep -wq "${extension}"; then
        echo "Failed to install PHP extension: ${extension}."
        exit 1
      fi
    done
    rm -rf /var/cache/apk/*
    echo "PHP extensions installed successfully."
  fi
}

# Set the timezone
if [ -n "${TIMEZONE}" ]; then
  ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime || { echo "Failed to set timezone to '${TIMEZONE}'."; exit 1; }
  echo "${TIMEZONE}" > /etc/timezone || { echo "Failed to set timezone to '${TIMEZONE}'."; exit 1; }
fi

# Replace placeholders with actual values in configuration files
sed -i "s|UPLOAD_MAX_SIZE|${UPLOAD_MAX_SIZE}|" ${NGINX_CONF} || { echo "Failed to replace placeholders in ${NGINX_CONF}."; exit 1; }
sed -i "s|INDEX_PATH|${INDEX_PATH}|;s|UPLOAD_MAX_SIZE|${UPLOAD_MAX_SIZE}|" ${NGINX_VIRTUAL_HOST_CONF} || { echo "Failed to replace placeholders in ${NGINX_VIRTUAL_HOST_CONF}."; exit 1; }
sed -i "s|MEMORY_LIMIT|${MEMORY_LIMIT}|;s|UPLOAD_MAX_SIZE|${UPLOAD_MAX_SIZE}|" ${PHP_INI} || { echo "Failed to replace placeholders in ${PHP_INI}."; exit 1; }
sed -i "s|MEMORY_LIMIT|${MEMORY_LIMIT}|" ${PHP_FPM_CONF} || { echo "Failed to replace placeholders in ${PHP_FPM_CONF}."; exit 1; }

# Check if the SUPERVISOR_CONF environment variable is set
if [ -n "${SUPERVISOR_CONF}" ]; then
  # Check if the file exists
  if [ -f "${SUPERVISOR_CONF}" ]; then
    cp -f "${SUPERVISOR_CONF}" /etc/supervisor/conf/"${SUPERVISOR_CONF##*/}" || { echo "Failed to copy the file '${SUPERVISOR_CONF}' to '/etc/supervisor/conf.d/'."; exit 1; }
  else
    echo "The file specified in SUPERVISOR_CONF does not exist."
    exit 1
  fi
fi


# Install the required PHP extensions
if [ -n "${PHP_EXTENSIONS}" ]; then
  check_and_install_extension
fi

# Create directory for the sock file
mkdir -p /var/run/php || { echo "Failed to create directory '/var/run/php'."; exit 1; }

# Set the correct permissions for the project directory and the sock file directory
chown -R nginx:www-data /var/www/html /var/run/php || { echo "Failed to set permissions for '/var/www/html' and '/var/run/php'."; exit 1; }

# Start supervisord
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf