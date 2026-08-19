#!/bin/sh
set -eu

echo "Checking Buildx builder"
docker buildx inspect --bootstrap >/dev/null

echo "Building linux/amd64 + linux/arm64 variants"
docker buildx bake multiarch

echo "Multi-architecture build passed."
