# Source and attribution

Original producer scripts are MIT licensed. SGFX and Scarlet retain their MIT
licenses, SDL2 retains its zlib license, and Mesa retains its per-file licenses
described by `docs/license.rst`. The runtime is not relicensed as a whole.
Top-level notices are installed under `/usr/share/doc/scarlet-linux-graphics/`.

The source export contains the exact fork trees in `sources.lock.json`,
including Mesa's notices for its individual components. Both Rust dependency
graphs are exported by `cargo vendor`, with their individual license files.
The pinned SWS standalone Cargo.lock is preserved beside its source.
Dependency-package binaries come from the caller's distribution; that
caller must retain its dpkg copyright metadata and matching Debian sources.
Compiler/toolchain binaries are not installed in this graphics runtime.

Ship `sources/` alongside the runtime/rootfs and retain both. A repository link
alone does not replace corresponding source distribution. Source and runtime
hashes, fixed revisions, compiler versions and ELF dependency requirements are
recorded in the build output. This is an independent Scarlet integration, not
an official Debian or Mesa release.
