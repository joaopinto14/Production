#!/bin/sh
set -eu

VERSION="${VERSION:-2.0.0-dev.6}"

for VARIANT in generic laravel; do
    for PHP_VERSION in 8.3 8.4 8.5; do
        echo
        echo "============================================================"
        echo "Testing Production ${VERSION} / ${VARIANT} / PHP ${PHP_VERSION}"
        echo "============================================================"
        VARIANT="${VARIANT}" PHP_VERSION="${PHP_VERSION}" VERSION="${VERSION}" ./tests/smoke.sh
    done
done

echo
echo "All generic and Laravel PHP variants passed."
