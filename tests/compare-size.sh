#!/bin/sh
set -eu

BASE_VERSION="${BASE_VERSION:-2.0.0-dev.3}"
TARGET_VERSION="${TARGET_VERSION:-2.0.0-dev.4}"

printf '%-8s %15s %15s %15s\n' 'PHP' 'dev.3 bytes' 'dev.4 bytes' 'difference'
printf '%-8s %15s %15s %15s\n' '---' '-----------' '-----------' '----------'

for PHP_VERSION in 8.3 8.4 8.5; do
    base="production:${BASE_VERSION}-php${PHP_VERSION}"
    target="production:${TARGET_VERSION}-php${PHP_VERSION}"

    docker image inspect "${base}" >/dev/null 2>&1 || {
        echo "Missing base image: ${base}" >&2
        exit 1
    }
    docker image inspect "${target}" >/dev/null 2>&1 || {
        echo "Missing target image: ${target}" >&2
        exit 1
    }

    base_size="$(docker image inspect "${base}" --format='{{.Size}}')"
    target_size="$(docker image inspect "${target}" --format='{{.Size}}')"
    diff=$((target_size - base_size))

    printf '%-8s %15s %15s %+15d\n' "${PHP_VERSION}" "${base_size}" "${target_size}" "${diff}"
done
