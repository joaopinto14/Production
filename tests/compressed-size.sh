#!/bin/sh
# A failed save or compressor must fail the measurement.
compressed_size() (
    set -eu
    size_directory="$(mktemp -d)" || exit 1
    trap 'rm -rf "${size_directory}"' EXIT
    trap 'exit 1' INT TERM
    docker image save --output "${size_directory}/image.tar" "$1" || exit 1
    gzip -c "${size_directory}/image.tar" > "${size_directory}/image.tar.gz" || exit 1
    wc -c < "${size_directory}/image.tar.gz"
)
