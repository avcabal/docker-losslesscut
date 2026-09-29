ARG DOCKER_IMAGE_VERSION=

ARG LOSSLESSCUT_VERSION=3.69.0
# ffmpeg is pinned independently of LosslessCut: the bundled build (8.0) has a
# regression for us, so we drop in a controlled one.
ARG FFMPEG_VERSION=8.1

# Debian (glibc) is required: LosslessCut ships a prebuilt Electron binary that
# will not run on the musl-based Alpine variant.
FROM jlesage/baseimage-gui:debian-12-v4.14.0

ARG LOSSLESSCUT_VERSION
ARG FFMPEG_VERSION
ARG DOCKER_IMAGE_VERSION
ARG TARGETARCH

WORKDIR /tmp

# Chromium/Electron runtime libraries.
RUN \
    add-pkg \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libatspi2.0-0 \
        libcairo2 \
        libcups2 \
        libdrm2 \
        libgbm1 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libpulse0 \
        libsecret-1-0 \
        libx11-xcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxkbcommon0 \
        libxrandr2 \
        libxshmfence1 \
        fonts-dejavu-core

# Install LosslessCut, then replace its bundled ffmpeg with a pinned static
# build. LosslessCut runs ffmpeg/ffprobe from resources/.
RUN \
    add-pkg --virtual build-deps ca-certificates curl bzip2 xz-utils && \
    case "${TARGETARCH:-amd64}" in \
        amd64) LC_ARCH=x64; FF_ARCH=64 ;; \
        arm64) LC_ARCH=arm64; FF_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    mkdir -p /opt/losslesscut && \
    curl -fsSL "https://github.com/mifi/lossless-cut/releases/download/v${LOSSLESSCUT_VERSION}/LosslessCut-linux-${LC_ARCH}.tar.bz2" \
        | tar xj -C /opt/losslesscut --strip-components=1 && \
    rm -f /opt/losslesscut/chrome-sandbox && \
    rm -f /opt/losslesscut/resources/libav*.so* \
          /opt/losslesscut/resources/libsw*.so* \
          /opt/losslesscut/resources/libpostproc*.so* && \
    curl -fsSL "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n${FFMPEG_VERSION}-latest-linux${FF_ARCH}-gpl-${FFMPEG_VERSION}.tar.xz" \
        | tar xJ -C /opt/losslesscut/resources --strip-components=2 --wildcards '*/bin/ffmpeg' '*/bin/ffprobe' && \
    del-pkg build-deps

COPY icon.png /tmp/icon.png
RUN install_app_icon.sh /tmp/icon.png && rm -f /tmp/icon.png

COPY rootfs/ /
RUN chmod +x /startapp.sh

RUN \
    set-cont-env APP_NAME "LosslessCut" && \
    set-cont-env APP_VERSION "$LOSSLESSCUT_VERSION" && \
    set-cont-env DOCKER_IMAGE_VERSION "$DOCKER_IMAGE_VERSION" && \
    true

# Audio preview matters for a video editor, so default WEB_AUDIO on (base is off).
ENV \
    LOSSLESSCUT_EXTRA_ARGS= \
    WEB_AUDIO=1

VOLUME ["/storage"]

LABEL \
      org.label-schema.name="losslesscut" \
      org.label-schema.description="Docker container for LosslessCut" \
      org.label-schema.version="${DOCKER_IMAGE_VERSION:-}" \
      org.label-schema.vcs-url="https://github.com/RabbitsInMotion/docker-losslesscut" \
      org.label-schema.schema-version="1.0"
