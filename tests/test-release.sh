#!/bin/sh
set -eu

./tests/test-all.sh
./tests/multiarch-build.sh

printf '%s\n' 'Release-level test suite passed, including multi-architecture builds.'
