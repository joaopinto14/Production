FROM alpine

LABEL maintainer="João Pinto [suport@joaopinto.pt]"

# Set environment variables
ENV MEMORY_LIMIT=512M \
    UPLOAD_LIMIT=100M

# Install PHP and Nginx
RUN apk update && apk add --no-cache \
    php \
    php-fpm \
    php-ctype \
    php-curl \
    php-dom \
    php-fileinfo \
    php-mbstring \
    php-openssl \
    php-pdo \
    php-pdo_mysql \
    php-session \
    php-tokenizer \
    php-xml \
    nginx

# Limit memory and upload size
RUN echo "memory_limit = ${MEMORY_LIMIT}" > /etc/php82/conf.d/memory-limit.ini && \
    echo "upload_max_filesize = ${UPLOAD_LIMIT}" > /etc/php82/conf.d/upload-limit.ini && \
    echo "post_max_size = ${UPLOAD_LIMIT}" >> /etc/php82/conf.d/upload-limit.ini

# Copy Nginx configuration file and custom startup script
COPY nginx/default.conf /etc/nginx/http.d/default.conf
COPY entrypoint/entrypoint.sh /usr/local/bin/entrypoint.sh

# Make the startup script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose web server port and set healthcheck
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=30s CMD curl --fail http://localhost:80 || exit 1

CMD ["entrypoint.sh"]