ARG LOSSLESSCUT_VERSION=3.69.0

# ffmpeg replaces the build LosslessCut bundles. LosslessCut 3.69.0 ships
# n8.0-23 (2025-10-22), which lacks the fix for
# https://trac.ffmpeg.org/ticket/11490 (FFmpeg commit ae03b629: old-style
# uncompressed PCM in MOV/MP4 demuxes to no packets). The fix is in n8.0.2+,
# n8.1+ and n9.0+.
# Pinned to a BtbN month-end autobuild: BtbN keeps those long term, while
# "latest" and daily builds are pruned. To update, pick a newer month-end
# autobuild-* release and copy the sha256 digests of both tarballs.
ARG FFMPEG_BUILD=autobuild-2026-08-31-13-27
ARG FFMPEG_RELEASE=n8.1.2-50-g1a748fe2cd
ARG FFMPEG_BRANCH=8.1
ARG FFMPEG_SHA256_AMD64=c733b4b2951e5957e15505f788b2c65a7a41b6da4b289e295852cc38079b4d2b
ARG FFMPEG_SHA256_ARM64=ae5da4f51b9052390f414005f8ab26c1eed1268f327cce7cb79aa076b29bd66e
# The build fails if ffmpeg reports an older version than this.
ARG FFMPEG_MIN_VERSION=8.1

# Debian (glibc) is required: LosslessCut ships a prebuilt Electron binary that
# will not run on musl. The tag is a multi-arch manifest (amd64 + arm64).
FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie

ARG LOSSLESSCUT_VERSION
ARG FFMPEG_BUILD
ARG FFMPEG_RELEASE
ARG FFMPEG_BRANCH
ARG FFMPEG_SHA256_AMD64
ARG FFMPEG_SHA256_ARM64
ARG FFMPEG_MIN_VERSION
ARG DOCKER_IMAGE_VERSION=
ARG TARGETARCH

# NO_GAMEPAD and NO_WEBCAM skip the virtual device setup. The base checks only
# whether they are set, so any value (even "false") disables the device.
# File transfers, webcam and microphone are off; "|locked" stops the browser
# client from turning them back on.
# SELKIES_ENCODER: the first entry is the default stream codec (H.265); the rest
# stay available, and browsers that cannot decode H.265 fall back down the list.
ENV \
    TITLE=LosslessCut \
    NO_GAMEPAD=true \
    SELKIES_GAMEPAD_ENABLED=false \
    SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false \
    NO_WEBCAM=true \
    SELKIES_WEBCAM_ENABLED="false|locked" \
    SELKIES_UI_SIDEBAR_SHOW_WEBCAM=false \
    SELKIES_MICROPHONE_ENABLED="false|locked" \
    SELKIES_FILE_TRANSFERS=none \
    SELKIES_UI_SIDEBAR_SHOW_FILES=false \
    SELKIES_UI_SIDEBAR_SHOW_APPS=false \
    NO_DECOR=true \
    SELKIES_ENCODER="h265enc,h264enc,vp8enc,vp9enc,av1enc,jpeg" \
    LOSSLESSCUT_EXTRA_ARGS=

# Install Electron runtime libraries and LosslessCut, then swap LosslessCut's
# bundled shared ffmpeg for the pinned static build. LosslessCut runs
# resources/ffmpeg and resources/ffprobe.
RUN \
    echo "**** install packages ****" && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bzip2 \
        xz-utils \
        libasound2t64 \
        libatk-bridge2.0-0t64 \
        libatk1.0-0t64 \
        libcups2t64 \
        libgbm1 \
        libgtk-3-0t64 \
        libnss3 \
        libsecret-1-0 \
        libxss1 && \
    echo "**** install losslesscut ****" && \
    case "${TARGETARCH:-amd64}" in \
        amd64) LC_ARCH=x64; FF_ARCH=64; FF_SHA256="${FFMPEG_SHA256_AMD64}" ;; \
        arm64) LC_ARCH=arm64; FF_ARCH=arm64; FF_SHA256="${FFMPEG_SHA256_ARM64}" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    mkdir -p /opt/losslesscut && \
    curl -fsSL "https://github.com/mifi/lossless-cut/releases/download/v${LOSSLESSCUT_VERSION}/LosslessCut-linux-${LC_ARCH}.tar.bz2" \
        | tar xj -C /opt/losslesscut --strip-components=1 && \
    rm -f /opt/losslesscut/chrome-sandbox && \
    echo "**** replace bundled ffmpeg ****" && \
    rm -f \
        /opt/losslesscut/resources/ffmpeg \
        /opt/losslesscut/resources/ffprobe \
        /opt/losslesscut/resources/libav*.so* \
        /opt/losslesscut/resources/libpostproc*.so* \
        /opt/losslesscut/resources/libsw*.so* && \
    FF_NAME="ffmpeg-${FFMPEG_RELEASE}-linux${FF_ARCH}-gpl-${FFMPEG_BRANCH}" && \
    curl -fsSL -o /tmp/ffmpeg.tar.xz \
        "https://github.com/BtbN/FFmpeg-Builds/releases/download/${FFMPEG_BUILD}/${FF_NAME}.tar.xz" && \
    echo "${FF_SHA256}  /tmp/ffmpeg.tar.xz" | sha256sum -c - && \
    tar xJf /tmp/ffmpeg.tar.xz -C /opt/losslesscut/resources --strip-components=2 \
        "${FF_NAME}/bin/ffmpeg" "${FF_NAME}/bin/ffprobe" && \
    echo "**** verify ffmpeg ****" && \
    /opt/losslesscut/resources/ffprobe -hide_banner -version > /dev/null && \
    FF_VERSION="$(/opt/losslesscut/resources/ffmpeg -hide_banner -version | sed -n '1s/^ffmpeg version n\{0,1\}\([0-9][0-9.]*\).*/\1/p')" && \
    echo "ffmpeg ${FF_VERSION}" && \
    if [ -z "${FF_VERSION}" ] || \
       [ "$(printf '%s\n%s\n' "${FFMPEG_MIN_VERSION}" "${FF_VERSION}" | sort -V | head -n1)" != "${FFMPEG_MIN_VERSION}" ]; then \
        echo "ffmpeg '${FF_VERSION}' is older than ${FFMPEG_MIN_VERSION}" >&2; exit 1; \
    fi && \
    echo "**** cleanup ****" && \
    apt-get autoclean && \
    rm -rf \
        /config/.cache \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

COPY icon.png /usr/share/selkies/www/icon.png
COPY icon.png /usr/share/icons/hicolor/512x512/apps/losslesscut.png
COPY root/ /

LABEL \
      org.opencontainers.image.title="losslesscut" \
      org.opencontainers.image.description="LosslessCut in a browser, on the LinuxServer Selkies base image" \
      org.opencontainers.image.version="${DOCKER_IMAGE_VERSION}" \
      org.opencontainers.image.source="https://github.com/avcabal/docker-losslesscut"