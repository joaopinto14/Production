#!/bin/sh

# Variables
TIMEZONE=${TIMEZONE:-}
PHP_EXTENSIONS=${PHP_EXTENSIONS:-}
MEMORY_LIMIT=${MEMORY_LIMIT:-128M}
UPLOAD_MAX_SIZE=${UPLOAD_MAX_SIZE:-8M}
INDEX_PATH=${INDEX_PATH:-/var/www/html}
SUPERVISOR_CONF=${SUPERVISOR_CONF:-}

NGINX_CONF="/etc/nginx/nginx.conf"
NGINX_VIRTUAL_HOST_CONF="/etc/nginx/http.d/default.conf"
PHP_SETTINGS="/etc/php83/conf.d/settings.ini"
PHP_WWW="/etc/php83/php-fpm.d/www.conf"

# Functions

# Function to verify if the 'index.php' file exists in the path specified in INDEX_PATH
verify_index_file() {
    if [ ! -f "${INDEX_PATH}/index.php" ]; then
        echo "The path specified in INDEX_PATH does not contain the 'index.php' file."
        exit 1
    fi
}

# Function to set the timezone
set_timezone() {
    echo "Setting timezone to $TIMEZONE"
    # Check if the timezone is valid
    if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
        cp "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime || { echo "Failed to set timezone"; exit 1;}
        echo "$TIMEZONE" > /etc/timezone || { echo "Failed to set timezone"; exit 1;}
    else
        echo "Timezone '$TIMEZONE' is not valid"
        exit 1
    fi
}

# Function to install additional PHP extensions
install_php_extensions() {
    echo "Installing PHP extensions..."
    installed_extensions=$(php -m | tr '[:upper:]' '[:lower:]')
    php_extensions=$(echo "${PHP_EXTENSIONS}" | tr '[:upper:]' '[:lower:]')

    # Install PHP extensions
    for extension in ${php_extensions}; do
        if ! echo "${installed_extensions}" | grep -wq "${extension}"; then
            apk add -q --no-cache php83-"${extension}" > /dev/null 2>&1
            if ! php -m | tr '[:upper:]' '[:lower:]' | grep -wq "${extension}"; then
                echo "Failed to install PHP extension: ${extension}."
                exit 1
            fi
        fi
    done

    # Clean cache
    rm -rf /var/cache/apk/*
    echo "PHP extensions installed successfully."
}

# Function to replace placeholders in configuration files
replace_placeholders() {
    sed -i "s|UPLOAD_MAX_SIZE|${UPLOAD_MAX_SIZE}|" ${NGINX_CONF} || { echo "Failed to replace placeholders in ${NGINX_CONF}."; exit 1; }
    sed -i "s|INDEX_PATH|${INDEX_PATH}|;s|UPLOAD_MAX_SIZE|${UPLOAD_MAX_SIZE}|" ${NGINX_VIRTUAL_HOST_CONF} || { echo "Failed to replace placeholders in ${NGINX_VIRTUAL_HOST_CONF}."; exit 1; }
    sed -i "s|MEMORY_LIMIT|${MEMORY_LIMIT}|;s|UPLOAD_MAX_SIZE|${UPLOAD_MAX_SIZE}|" ${PHP_SETTINGS} || { echo "Failed to replace placeholders in ${PHP_SETTINGS}."; exit 1; }
    sed -i "s|MEMORY_LIMIT|${MEMORY_LIMIT}|" ${PHP_WWW} || { echo "Failed to replace placeholders in ${PHP_WWW}."; exit 1; }
}

# Function to set the Supervisor configuration
set_config_supervisor() {
    echo "Setting up Supervisor configuration..."
    if [ -f "${SUPERVISOR_CONF}" ]; then
        cp -f "${SUPERVISOR_CONF}" /etc/supervisor/conf/"${SUPERVISOR_CONF##*/}" || { echo "Failed to copy the file '${SUPERVISOR_CONF}' to '/etc/supervisor/conf.d/'."; exit 1; }
    else
        echo "Supervisor configuration not found at ${SUPERVISOR_CONF}."
        exit 1
    fi
}

# Function to set permissions for the project directory
set_permissions_directory_project() {
    chown -R www:www /var/www/html || { echo "Failed to set permissions for '/var/www/html'."; exit 1; }
}


# Main

verify_index_file
replace_placeholders

if [ -n "$TIMEZONE" ]; then
    set_timezone
fi

if [ -n "$PHP_EXTENSIONS" ]; then
    install_php_extensions
fi

if [ -n "$SUPERVISOR_CONF" ]; then
    set_config_supervisor
fi

set_permissions_directory_project

# Start supervisord
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf