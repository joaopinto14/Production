#!/bin/sh
set -eu

. ./tests/lib.sh

section "Image size regression budgets"

# These budgets intentionally include headroom for Alpine/PHP patch releases,
# while still catching regressions such as reintroducing Python/Supervisor.
check_budget() {
    variant="$1"
    php_version="$2"
    budget="$3"
    image="$(image_for "${variant}" "${php_version}")"
    ensure_image "${image}"
    size="$(docker image inspect "${image}" --format '{{.Size}}')"

    log "${image}: ${size} bytes (budget ${budget})"
    [ "${size}" -le "${budget}" ] || fail "Image size regression: ${image} is ${size} bytes, budget is ${budget}."
}

check_budget generic 8.3 18000000
check_budget generic 8.4 18000000
check_budget generic 8.5 21000000
check_budget laravel 8.3 24000000
check_budget laravel 8.4 25000000
check_budget laravel 8.5 27000000

printf '%s\n' 'Image size budgets passed.'
