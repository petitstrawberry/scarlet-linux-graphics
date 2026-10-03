# Scarlet Linux graphics producer

Build the Linux ABI SGFX Vulkan ICD, its SWS C binding, Mesa Zink/Kopper and
the shared SDL2 EGL correction as a rootfs overlay. Native SWS and Wayland
bridge remain in Scarlet's desktop bundle. OpenTTD and other games are separate
application bundles.

The caller owns the build distribution, package installation and final rootfs.
`producer/build.sh OUTPUT` runs in an AArch64 Linux environment with the
packages listed in `producer/build-packages.txt` and the pinned Rust toolchain.
The output has `runtime/` (copy to the Linux rootfs) and `sources/` (ship with
the binary rootfs). Install `producer/runtime-packages.txt` in that rootfs.
The caller can provide `GRAPHICS_WORK`, `BUILD_JOBS` and `GRAPHICS_REVISION`.
Source revisions in `producer/sources.lock.json` are exact commits, including
the merged Scarlet and SGFX changes; no development-branch checkout is needed.

The supplied Dockerfile demonstrates the contract on Debian 13 trixie:

```sh
bash producer/build_container.sh
```

This builds and checks the minimal runtime image, then exports both directories
under `artifacts/`. GitHub's manual workflow produces a build artifact only;
it does not publish releases. The Debian bundle producer consumes this repo as
a revision-pinned additional build context, using Debian stages and signed APT
indexes for both dependency installation and corresponding source collection.

Install paths are Linux ABI paths, rooted at `/systems/linux-aarch64` when
viewed from Scarlet. The ICD and `libsws_client_c.so` are in
`/usr/lib/aarch64-linux-gnu`, the standard ICD JSON in
`/usr/share/vulkan/icd.d`, private Mesa in `/opt/sgfx-zink`, and private SDL in
`/opt/sgfx-sdl`. Debian-owned Mesa/SDL files are not overwritten. The runtime
depends on glibc and Wayland libraries; it is not a universal musl/glibc binary.

On a Scarlet desktop with the matching SWS/bridge protocols:

```sh
# Scarlet-native terminal; use the same socket in the app terminal.
XDG_RUNTIME_DIR=/tmp WAYLAND_DISPLAY=wayland-graphics /bin/wayland-bridge

# Separate terminal. Substitute an installed Linux ABI application.
XDG_RUNTIME_DIR=/tmp WAYLAND_DISPLAY=wayland-graphics \
  abi-run linux-aarch64 /usr/local/bin/scarlet-gl /path/to/application
```

`scarlet-gl` selects Zink, SGFX's ICD, private Mesa/SDL and the no-DRM Kopper
route for that process. It removes software-renderer and GL-version override
variables. Without arguments it runs the renderer/error/readback/window probe.
The legacy `/opt/sgfx-vulkan-tests/zink-window-run` entry point is retained for
the existing OpenTTD launcher. No global environment or desktop service is
changed. A successful dependency-loader check is not evidence of GPU execution.

The original OpenTTD validation used AArch64 QEMU/VirGL on Scarlet. Real hardware
and full Vulkan conformance are not established. The OpenTTD fullscreen viewport
limitation remains unresolved; use windowed mode. Rebuilding in Debian changes
the build environment, so the old game screenshots do not validate new binaries.

`manifest.json` records source pins, tools, runtime hashes and ELF dependencies.
Corresponding source output includes exact Git trees, Rust dependencies from
`cargo vendor`, both lockfiles and build recipes. See `ATTRIBUTION.md`.
