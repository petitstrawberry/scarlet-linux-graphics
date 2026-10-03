#!/bin/sh
set -eu
test -s /usr/share/vulkan/icd.d/sgfx.json
test -s /usr/share/doc/scarlet-linux-graphics/manifest.json
test -s /opt/sgfx-zink/share/glvnd/egl_vendor.d/50_mesa.json
test -x /opt/sgfx-vulkan-tests/zink-window
test -x /usr/local/bin/scarlet-gl
export LD_LIBRARY_PATH=/opt/sgfx-sdl/lib:/opt/sgfx-zink/lib/aarch64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
/usr/libexec/scarlet-graphics-loader-check
for directory in /opt/sgfx-sdl/lib /opt/sgfx-zink/lib/aarch64-linux-gnu; do
    find "$directory" -type f -name '*.so*' -exec ldd '{}' \; > /tmp/scarlet-graphics-ldd.txt
    if grep -q 'not found' /tmp/scarlet-graphics-ldd.txt; then
        cat /tmp/scarlet-graphics-ldd.txt >&2
        exit 1
    fi
done
echo SCARLET_LINUX_GRAPHICS_LOAD_OK
# This checks the Linux ABI/dependency closure, not GPU execution on Scarlet.
