# Standalone reference builder. Debian bundle supplies its own equivalent stages.
FROM debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a AS builder
COPY producer/build-packages.txt /tmp/build-packages.txt
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $(cat /tmp/build-packages.txt)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --profile minimal --default-toolchain nightly-2025-12-31
ENV PATH="/root/.cargo/bin:${PATH}"
COPY . /graphics-producer
ARG GRAPHICS_REVISION=local
ARG BUILD_JOBS=4
ARG GRAPHICS_INPUT_KEY=local
RUN --mount=type=cache,id=scarlet-linux-graphics-registry,target=/root/.cargo/registry \
    --mount=type=cache,id=scarlet-linux-graphics-git,target=/root/.cargo/git \
    --mount=type=cache,id=scarlet-linux-graphics-work-${GRAPHICS_INPUT_KEY},target=/graphics-work \
    GRAPHICS_REVISION="$GRAPHICS_REVISION" BUILD_JOBS="$BUILD_JOBS" bash /graphics-producer/producer/build.sh /out

FROM debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a AS runtime
COPY producer/runtime-packages.txt /tmp/runtime-packages.txt
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $(cat /tmp/runtime-packages.txt) && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/runtime-packages.txt
COPY --from=builder /out/runtime/ /
RUN sh /usr/share/scarlet/smoke_graphics.sh

FROM scratch AS export
COPY --from=builder /out/ /
