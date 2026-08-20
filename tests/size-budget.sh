#!/bin/sh
set -eu

. ./tests/lib.sh

section "Compressed image size regression budgets"

# docker image inspect .Size is not consistent enough across Docker
# storage backends/builders for a release regression budget.
#
# Measure a compressed docker archive instead. This gives us a portable
# approximation of the size transferred/stored by a registry.
compressed_size() {
    image="$1"

    docker image save "${image}" \
        | gzip -c \
        | wc -c \
        | tr -d '[:space:]'
}

check_budget() {
    variant="$1"
    php_version="$2"
    budget="$3"

    image="$(image_for "${variant}" "${php_version}")"

    ensure_image "${image}"

    size="$(compressed_size "${image}")"

    log "${image}: ${size} compressed bytes (budget ${budget})"

    [ "${size}" -le "${budget}" ] \
        || fail "Compressed image size regression: ${image} is ${size} bytes, budget is ${budget}."
}

# Budgets include enough room for Alpine/PHP patch releases while still
# detecting meaningful dependency/runtime regressions.
check_budget generic 8.3 20000000
check_budget generic 8.4 20000000
check_budget generic 8.5 23000000

check_budget laravel 8.3 28000000
check_budget laravel 8.4 29000000
check_budget laravel 8.5 32000000

printf '%s\n' 'Compressed image size budgets passed.'
