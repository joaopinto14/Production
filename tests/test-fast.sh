#!/bin/sh
set -eu

. ./tests/lib.sh

section "Fast developer test suite (PHP 8.5 only)"

./tests/static.sh
./tests/build-validation.sh

if [ "${SKIP_BUILD:-0}" != "1" ]; then
    VERSION="${TEST_VERSION}" IMAGE_NAME="${TEST_IMAGE_NAME}" docker buildx bake --load php85 laravel-php85
fi

PHP_VERSIONS='8.5' ./tests/image-contract.sh
PHP_VERSIONS='8.5' ./tests/smoke-all.sh
./tests/configuration.sh
./tests/http-contract.sh

printf '%s\n' 'Fast developer test suite passed.'
