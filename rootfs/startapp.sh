#!/bin/sh

# LosslessCut (Electron) stores its config under $HOME/.config/LosslessCut.
export HOME=/config

# Start the file-open dialog in the media volume when present.
cd /storage 2>/dev/null || cd /config

# --no-sandbox: the base image runs the app as a non-root user without the
#   namespaces Chromium's setuid sandbox needs.
# --disable-dev-shm-usage: avoid crashes when the container's /dev/shm is small.
exec /opt/losslesscut/losslesscut \
    --no-sandbox \
    --disable-dev-shm-usage \
    ${LOSSLESSCUT_EXTRA_ARGS:-} \
    "$@"

# vim:ft=sh:ts=4:sw=4:et:sts=4
