#!/bin/sh
set -eu

VERSION="${VERSION:-2.0.0-rc.1}"
PREVIOUS_VERSION="${PREVIOUS_VERSION:-2.0.0-dev.7}"
IMAGE_NAME="${IMAGE_NAME:-production}"

printf '%-8s %16s %16s %16s %14s\n' "PHP" "dev.7 generic" "rc.1 generic" "rc.1 laravel" "Laravel extra"
printf '%-8s %16s %16s %16s %14s\n' "---" "-------------" "------------" "------------" "-------------"

for PHP_VERSION in 8.3 8.4 8.5; do
    previous="${IMAGE_NAME}:${PREVIOUS_VERSION}-php${PHP_VERSION}"
    generic="${IMAGE_NAME}:${VERSION}-php${PHP_VERSION}"
    laravel="${IMAGE_NAME}:${VERSION}-laravel-php${PHP_VERSION}"

    previous_size="$(docker image inspect "${previous}" --format='{{.Size}}' 2>/dev/null || echo '-')"
    generic_size="$(docker image inspect "${generic}" --format='{{.Size}}' 2>/dev/null || echo '-')"
    laravel_size="$(docker image inspect "${laravel}" --format='{{.Size}}' 2>/dev/null || echo '-')"

    extra='-'
    if [ "${generic_size}" != '-' ] && [ "${laravel_size}" != '-' ]; then
        extra=$((laravel_size - generic_size))
    fi

    printf '%-8s %16s %16s %16s %14s\n' "${PHP_VERSION}" "${previous_size}" "${generic_size}" "${laravel_size}" "${extra}"
done
