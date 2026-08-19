#!/bin/sh
set -eu

VERSION="${VERSION:-2.0.0-dev.5}"
PREVIOUS_VERSION="${PREVIOUS_VERSION:-2.0.0-dev.4}"

printf '%-8s %14s %14s %14s %14s\n' "PHP" "dev.4 generic" "dev.5 generic" "dev.5 laravel" "Laravel extra"
printf '%-8s %14s %14s %14s %14s\n' "---" "-------------" "-------------" "-------------" "-------------"

for PHP_VERSION in 8.3 8.4 8.5; do
    previous="production:${PREVIOUS_VERSION}-php${PHP_VERSION}"
    generic="production:${VERSION}-php${PHP_VERSION}"
    laravel="production:${VERSION}-laravel-php${PHP_VERSION}"

    previous_size="$(docker image inspect "${previous}" --format='{{.Size}}' 2>/dev/null || echo '-')"
    generic_size="$(docker image inspect "${generic}" --format='{{.Size}}' 2>/dev/null || echo '-')"
    laravel_size="$(docker image inspect "${laravel}" --format='{{.Size}}' 2>/dev/null || echo '-')"

    extra='-'
    if [ "${generic_size}" != '-' ] && [ "${laravel_size}" != '-' ]; then
        extra=$((laravel_size - generic_size))
    fi

    printf '%-8s %14s %14s %14s %14s\n' "${PHP_VERSION}" "${previous_size}" "${generic_size}" "${laravel_size}" "${extra}"
done
