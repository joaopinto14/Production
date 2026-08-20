#!/bin/sh
set -eu

. ./tests/lib.sh

STARTED="$(date +%s)"

run_suite() {
    name="$1"
    shift
    started="$(date +%s)"
    section "${name}"
    "$@"
    finished="$(date +%s)"
    log "${name} completed in $((finished - started))s"
}

run_suite "1/11 Static validation" ./tests/static.sh
run_suite "2/11 Negative build validation" ./tests/build-validation.sh

if [ "${SKIP_BUILD:-0}" = "1" ]; then
    log "SKIP_BUILD=1: reusing existing images"
else
    run_suite "3/11 Build all six images" ./tests/build-images.sh
fi

run_suite "4/11 Image contracts" ./tests/image-contract.sh
run_suite "5/11 Smoke matrix" ./tests/smoke-all.sh
run_suite "6/11 Runtime configuration" ./tests/configuration.sh
run_suite "7/11 Deep HTTP contract" ./tests/http-contract.sh
run_suite "8/11 Concurrent workload" ./tests/concurrency.sh
run_suite "9/11 Logging contract" ./tests/logging.sh
run_suite "10/11 Crash + signal handling" ./tests/runtime-failure.sh
run_suite "11/11 Hardened security + size budgets" sh -c './tests/security.sh && ./tests/size-budget.sh'

FINISHED="$(date +%s)"
printf '\n%s\n' "All Production tests passed in $((FINISHED - STARTED))s."
