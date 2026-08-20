#!/bin/sh
set -eu

. ./tests/lib.sh

STARTED="$(date +%s)"

section "Production ${TEST_VERSION} stable release validation"

# Stable release validation is intentionally stricter and slower than normal CI:
# 1) rebuild everything without cache;
# 2) reuse those clean images for the comprehensive suite;
# 3) boot real PHP and Laravel applications;
# 4) verify repeated restarts / no zombies;
# 5) validate both target architectures.
./tests/clean-build.sh
SKIP_BUILD=1 ./tests/test-all.sh
./tests/release-contract.sh
./tests/real-generic.sh
./tests/real-laravel.sh
./tests/restart-stability.sh
NO_CACHE=1 ./tests/multiarch-build.sh

FINISHED="$(date +%s)"
printf '\n%s\n' "Stable release suite passed in $((FINISHED - STARTED))s, including real applications and amd64/arm64 builds."
