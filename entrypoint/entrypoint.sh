#!/bin/ash

# Define default values for environment variables if they are not set
PHP_EXTENSIONS=${PHP_EXTENSIONS:-}
INDEX_PATH=${INDEX_PATH:-/var/www/html}
MEMORY_LIMIT=${MEMORY_LIMIT:-128M}
UPLOAD_MAX=${UPLOAD_MAX:-8M}
SUPERVISOR_FILE=${SUPERVISOR_FILE:-}

# Define file paths
NGINX_CONF="/etc/nginx/http.d/default.conf"
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

# Replace placeholders with actual values in configuration files
sed -i "s|INDEX_PATH|${INDEX_PATH}|;s|UPLOAD_MAX|${UPLOAD_MAX}|" ${NGINX_CONF} || { echo "Failed to replace placeholders in ${NGINX_CONF}."; exit 1; }
sed -i "s|MEMORY_LIMIT|${MEMORY_LIMIT}|;s|UPLOAD_MAX|${UPLOAD_MAX}|" ${PHP_INI} || { echo "Failed to replace placeholders in ${PHP_INI}."; exit 1; }
sed -i "s|MEMORY_LIMIT|${MEMORY_LIMIT}|" ${PHP_FPM_CONF} || { echo "Failed to replace placeholders in ${PHP_FPM_CONF}."; exit 1; }

# Check if the SUPERVISOR_FILE environment variable is set
if [ -n "${SUPERVISOR_FILE}" ]; then
  # Check if the file exists
  if [ -f "${SUPERVISOR_FILE}" ]; then
    cp -f "${SUPERVISOR_FILE}" /etc/supervisor/conf.d/$(basename "${SUPERVISOR_FILE}") || { echo "Falha ao copiar o arquivo '${SUPERVISOR_FILE}' para '/etc/supervisor/conf.d/'."; exit 1; }
  else
    echo "The file specified in SUPERVISOR_FILE does not exist."
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