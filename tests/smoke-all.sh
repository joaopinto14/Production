#!/bin/sh
set -eu

. ./tests/lib.sh

section "Smoke tests for all image variants"

PHP_VERSIONS="${PHP_VERSIONS:-8.3 8.4 8.5}"
VARIANTS="${VARIANTS:-generic laravel}"

for variant in ${VARIANTS}; do
    for php_version in ${PHP_VERSIONS}; do
        VARIANT="${variant}" PHP_VERSION="${php_version}" VERSION="${TEST_VERSION}" IMAGE_NAME="${TEST_IMAGE_NAME}" ./tests/smoke.sh
    done
done

printf '%s\n' 'All smoke tests passed.'
