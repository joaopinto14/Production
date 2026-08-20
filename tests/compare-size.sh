#!/bin/sh
set -eu

VERSION="${VERSION:-2.0.0}"
PREVIOUS_VERSION="${PREVIOUS_VERSION:-2.0.0-rc.1}"
IMAGE_NAME="${IMAGE_NAME:-production}"

compressed_size() {
    image="$1"

    if ! docker image inspect "${image}" >/dev/null 2>&1; then
        printf '%s\n' '-'
        return
    fi

    docker image save "${image}" \
        | gzip -c \
        | wc -c \
        | tr -d '[:space:]'
}

printf '%-8s %16s %16s %16s %14s\n' \
    "PHP" "rc.1 generic" "2.0.0 generic" "2.0.0 laravel" "Laravel extra"

printf '%-8s %16s %16s %16s %14s\n' \
    "---" "-------------" "------------" "------------" "-------------"

for PHP_VERSION in 8.3 8.4 8.5; do
    previous="${IMAGE_NAME}:${PREVIOUS_VERSION}-php${PHP_VERSION}"
    generic="${IMAGE_NAME}:${VERSION}-php${PHP_VERSION}"
    laravel="${IMAGE_NAME}:${VERSION}-laravel-php${PHP_VERSION}"

    previous_size="$(compressed_size "${previous}")"
    generic_size="$(compressed_size "${generic}")"
    laravel_size="$(compressed_size "${laravel}")"

    extra='-'

    if [ "${generic_size}" != '-' ] && [ "${laravel_size}" != '-' ]; then
        extra=$((laravel_size - generic_size))
    fi

    printf '%-8s %16s %16s %16s %14s\n' \
        "${PHP_VERSION}" \
        "${previous_size}" \
        "${generic_size}" \
        "${laravel_size}" \
        "${extra}"
done
