#!/usr/bin/env bash
set -euo pipefail
producer_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:?usage: producer/build.sh <output-directory>}"
work="${GRAPHICS_WORK:-/graphics-work}"
jobs="${BUILD_JOBS:-4}"
case "$(uname -m)" in aarch64) ;; *) echo 'Only native AArch64 Linux builds are supported' >&2; exit 2 ;; esac
mkdir -p "$output" "$work"
output="$(cd "$output" && pwd)"
if [[ -e "$output/runtime" || -e "$output/sources" ]]; then
    echo 'Refusing to mix new output with an existing runtime/source export' >&2; exit 2
fi
mkdir -p "$output/runtime" "$output/sources/producer"
cp -a "$producer_root/producer" "$producer_root/runtime" "$producer_root/tests" \
    "$producer_root/LICENSE" "$producer_root/ATTRIBUTION.md" "$producer_root/README.md" "$output/sources/producer/"
python3 "$producer_root/producer/fetch_sources.py" "$work/inputs" "$output/sources"
sgfx="$work/inputs/sgfx"
scarlet="$work/inputs/scarlet"
mesa="$work/inputs/mesa"
sdl="$work/inputs/sdl"
target=aarch64-unknown-linux-gnu
toolchain="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["rust_toolchain"])' "$producer_root/producer/sources.lock.json")"
export RUSTUP_TOOLCHAIN="$toolchain"
export CARGO_BUILD_JOBS="$jobs"
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export SOURCE_DATE_EPOCH="$(git -C "$sgfx" show -s --format=%ct HEAD)"
cmp "$scarlet/tools/graphics/vulkan/scarlet-sgfx.xml" "$sgfx/crates/vulkan-sgfx/protocol/scarlet-sgfx.xml"

# Generate the standalone SDK lock in a work copy, never in the pinned input.
if [[ ! -d "$work/sdk" ]]; then cp -a "$scarlet/user/lib" "$work/sdk"; fi
sdk="$work/sdk/sws-client-c/Cargo.toml"
export CARGO_TARGET_DIR="$work/target-sws"
cp "$producer_root/producer/sws.Cargo.lock" "$work/sdk/sws-client-c/Cargo.lock"
cargo build --locked --release --target "$target" --manifest-path "$sdk"
cp "$work/sdk/sws-client-c/Cargo.lock" "$output/sources/upstream/scarlet/user/lib/sws-client-c/"
cargo vendor --locked --versioned-dirs --manifest-path "$sdk" "$output/sources/cargo-vendor-sws" \
    > "$output/sources/cargo-vendor-sws-config.toml"

export LD_LIBRARY_PATH="$CARGO_TARGET_DIR/$target/release${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export RUSTFLAGS="-Lnative=$CARGO_TARGET_DIR/$target/release"
export CARGO_TARGET_DIR="$work/target-sgfx"
cd "$sgfx"
cargo test --locked --release --target "$target" -p vulkan-sgfx --lib \
    --no-default-features --features scarlet-wsi
cargo build --locked --release --target "$target" -p vulkan-sgfx --lib \
    --no-default-features --features scarlet-wsi
cargo vendor --locked --versioned-dirs "$output/sources/cargo-vendor-sgfx" \
    > "$output/sources/cargo-vendor-sgfx-config.toml"
library="$output/runtime/usr/lib/aarch64-linux-gnu"
mkdir -p "$library" "$output/runtime/usr/share/vulkan/icd.d"
install -m 755 "$work/target-sws/$target/release/libsws_client_c.so" "$library/"
install -m 755 "$work/target-sgfx/$target/release/libvulkan_sgfx.so" "$library/"
install -m 644 "$scarlet/tools/graphics/vulkan/sgfx.json" "$output/runtime/usr/share/vulkan/icd.d/"

meson_arguments=()
if [[ -f "$work/mesa-build/meson-private/coredata.dat" ]]; then meson_arguments+=(--reconfigure); fi
meson setup "${meson_arguments[@]}" "$work/mesa-build" "$mesa" \
    --prefix=/opt/sgfx-zink --libdir=lib/aarch64-linux-gnu \
    -Dbuildtype=release -Db_ndebug=true \
    -Dgallium-drivers=zink,softpipe -Dvulkan-drivers= -Dplatforms=wayland \
    -Dglx=disabled -Degl=enabled -Dgbm=enabled -Dglvnd=enabled \
    -Dllvm=disabled -Dvideo-codecs= -Dgallium-vdpau=disabled -Dgallium-va=disabled
ninja -C "$work/mesa-build" -j "$jobs"
DESTDIR="$output/runtime" ninja -C "$work/mesa-build" install

cmake -S "$sdl" -B "$work/sdl-build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/sgfx-sdl \
    -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF -DSDL_TESTS=OFF \
    -DSDL_WAYLAND=ON -DSDL_WAYLAND_LIBDECOR=OFF -DSDL_X11=OFF -DSDL_KMSDRM=OFF
cmake --build "$work/sdl-build" --parallel "$jobs"
DESTDIR="$output/runtime" cmake --install "$work/sdl-build"

tests="$output/runtime/opt/sgfx-vulkan-tests"
mkdir -p "$tests" "$output/runtime/usr/local/bin" "$output/runtime/usr/libexec" "$output/runtime/usr/share/scarlet"
install -m 755 "$producer_root/runtime/scarlet-gl" "$output/runtime/usr/local/bin/"
# Preserve the entry point used by the existing OpenTTD launcher.
ln -s /usr/local/bin/scarlet-gl "$tests/zink-window-run"
cc -O2 -Wall -Wextra -Werror "$scarlet/guest_tests/linux_zink/window.c" \
    $(pkg-config --cflags --libs sdl2) -lGL -o "$tests/zink-window"
cc -O2 -Wall -Wextra -Werror "$scarlet/guest_tests/linux_zink/egl.c" -lEGL -o "$tests/zink-egl"
cc -O2 -Wall -Wextra -Werror "$scarlet/guest_tests/linux_vulkan/offscreen.c" -ldl -o "$tests/vulkan-offscreen"
cc -O2 -Wall -Wextra -Werror "$producer_root/tests/loader.c" -ldl \
    -o "$output/runtime/usr/libexec/scarlet-graphics-loader-check"
install -m 755 "$producer_root/tests/smoke_graphics.sh" "$output/runtime/usr/share/scarlet/"
documentation="$output/runtime/usr/share/doc/scarlet-linux-graphics"
mkdir -p "$documentation/licenses"
cp "$producer_root/LICENSE" "$producer_root/ATTRIBUTION.md" "$producer_root/README.md" \
    "$producer_root/producer/sources.lock.json" "$documentation/"
cp "$sgfx/LICENSE" "$documentation/licenses/SGFX"
cp "$scarlet/LICENSE" "$documentation/licenses/Scarlet"
cp "$mesa/docs/license.rst" "$documentation/licenses/Mesa"
cp "$sdl/LICENSE.txt" "$documentation/licenses/SDL"
python3 "$producer_root/producer/write_manifest.py" "$output" "${GRAPHICS_REVISION:-local}"
(cd "$output/sources"; find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$output/source-files.sha256"
printf 'Graphics runtime: %s/runtime\nCorresponding sources: %s/sources\n' "$output" "$output"
