#!/bin/sh
set -eu

./tests/smoke-all.sh
./tests/runtime-failure.sh
./tests/security.sh

echo
printf '%s\n' 'All Production tests passed.'
