#!/bin/sh
set -eu

for PHP_VERSION in 8.3 8.4 8.5; do
    echo
    echo "============================================================"
    echo "Testing Production ${VERSION:-2.0.0-dev.4} with PHP ${PHP_VERSION}"
    echo "============================================================"
    PHP_VERSION="${PHP_VERSION}" VERSION="${VERSION:-2.0.0-dev.4}" ./tests/smoke.sh
done

echo
echo "All PHP variants passed."
