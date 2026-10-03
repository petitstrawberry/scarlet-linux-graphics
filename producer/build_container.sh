#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${GRAPHICS_OUTPUT:-$root/artifacts}"
mkdir -p "$output"
if [[ -e "$output/runtime" || -e "$output/sources" ]]; then
    echo 'Choose a fresh GRAPHICS_OUTPUT directory' >&2; exit 2
fi
revision="$(git -C "$root" rev-parse HEAD)"
input_key="$(shasum -a 256 "$root/producer/sources.lock.json" | cut -d ' ' -f 1)"
stage="$(mktemp -d "$output/validation.XXXXXXXX")"
docker build --platform linux/arm64 --target runtime --build-arg GRAPHICS_REVISION="$revision" --build-arg GRAPHICS_CACHE_ID="$input_key" \
    --iidfile "$stage/runtime.id" -f "$root/producer/Dockerfile" "$root"
docker run --rm --network none --platform linux/arm64 "$(cat "$stage/runtime.id")" \
    sh /usr/share/scarlet/smoke_graphics.sh
docker build --platform linux/arm64 --target export --build-arg GRAPHICS_REVISION="$revision" --build-arg GRAPHICS_CACHE_ID="$input_key" \
    --output "type=local,dest=$output" -f "$root/producer/Dockerfile" "$root"
echo "Exported runtime and sources: $output"
