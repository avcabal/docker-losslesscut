# docker-losslesscut

[LosslessCut](https://github.com/mifi/lossless-cut) in a browser, built on
[linuxserver/baseimage-selkies](https://github.com/linuxserver/docker-baseimage-selkies)
(Debian trixie). `amd64` and `arm64` supported.

## ffmpeg

The image replaces the ffmpeg that LosslessCut bundles with a pinned static
[BtbN](https://github.com/BtbN/FFmpeg-Builds) build of **8.1**. LosslessCut
3.69.0 ships ffmpeg n8.0-23, which has
[ffmpeg ticket #11490](https://trac.ffmpeg.org/ticket/11490): MOV/MP4 files
with old-style uncompressed PCM audio demux to no audio packets. The fix
(FFmpeg commit `ae03b629`) is in 8.0.2+, 8.1+ and 9.0+.

The build checks the tarball's sha256 and fails if ffmpeg reports a version
older than `FFMPEG_MIN_VERSION`. The pin uses a BtbN month-end
`autobuild-*` release, because BtbN deletes `latest` branches and daily builds.

To update ffmpeg, pick a newer month-end release on the
[BtbN releases page](https://github.com/BtbN/FFmpeg-Builds/releases). Copy its
tag, the `ffmpeg-n8.1…` file prefix and the sha256 digests of the
`linux64-gpl-8.1` and `linuxarm64-gpl-8.1` tarballs into the build args below.

## Build

```sh
docker build -t ghcr.io/avcabal/losslesscut:26.09.1 .

# override the LosslessCut release:
docker build --build-arg LOSSLESSCUT_VERSION=3.69.0 -t ghcr.io/avcabal/losslesscut:custom .
```

| Build arg              | Default                          | Purpose                                      |
|------------------------|----------------------------------|----------------------------------------------|
| `LOSSLESSCUT_VERSION`  | `3.69.0`                         | LosslessCut release                          |
| `FFMPEG_BUILD`         | `autobuild-2026-08-31-13-27`     | BtbN release tag                             |
| `FFMPEG_RELEASE`       | `n8.1.2-50-g1a748fe2cd`          | ffmpeg version in the tarball file name      |
| `FFMPEG_BRANCH`        | `8.1`                            | ffmpeg branch in the tarball file name       |
| `FFMPEG_SHA256_AMD64`  | `c733b4b2…`                      | sha256 of the `linux64` tarball              |
| `FFMPEG_SHA256_ARM64`  | `ae5da4f5…`                      | sha256 of the `linuxarm64` tarball           |
| `FFMPEG_MIN_VERSION`   | `8.1`                            | Build fails if ffmpeg is older than this     |

### Build and run locally

Only Docker is needed. Build for your machine's architecture and start a
throwaway container:

```sh
git clone https://github.com/avcabal/docker-losslesscut.git
cd docker-losslesscut

docker build -t losslesscut:local .

docker run --rm -it \
  --name losslesscut \
  -p 3001:3001 \
  -e PUID=$(id -u) -e PGID=$(id -g) \
  -v "$PWD/config:/config" \
  -v /path/to/media:/storage \
  --shm-size=1gb \
  losslesscut:local
```

Open <https://localhost:3001> and accept the self-signed certificate. Stop with
`Ctrl+C`. LosslessCut settings stay in `./config`. The build fails early if the
bundled ffmpeg cannot run.

To build the other architecture (for example `arm64` on an `amd64` host),
register QEMU emulation once, then use Buildx:

```sh
docker run --privileged --rm tonistiigi/binfmt --install arm64
docker buildx build --platform linux/arm64 -t losslesscut:local-arm64 --load .
```

## Run

```sh
docker run -d \
  --name losslesscut \
  -p 3001:3001 \
  -e PUID=1000 -e PGID=1000 \
  -e TZ=America/Los_Angeles \
  -v losslesscut-config:/config \
  -v /path/to/media:/storage \
  --shm-size=1gb \
  ghcr.io/avcabal/losslesscut:26.09.1
```

Open <https://localhost:3001> and accept the self-signed certificate. Images
are published to `ghcr.io/avcabal/losslesscut` on tag (see
`.github/workflows/build-image.yml`).

The web UI has no login by default. Set `CUSTOM_USER` and `PASSWORD`, or put
the container behind an authenticating reverse proxy, before exposing it
beyond localhost.

## Ports

| Port | Purpose                                  |
|------|------------------------------------------|
| 3000 | Web UI over HTTP (needs a proxy for TLS) |
| 3001 | Web UI over HTTPS (self-signed)          |

## Volumes

| Path       | Purpose                                                   |
|------------|-----------------------------------------------------------|
| `/config`  | Home directory; LosslessCut settings in `.config/LosslessCut` |
| `/storage` | Your media; LosslessCut starts here when mounted          |

Only `/config` persists across image updates.

## Environment variables

All [Selkies base image variables](https://docs.linuxserver.io/selkies/user-guide/configuration/)
apply (`PUID`, `PGID`, `CUSTOM_USER`, `PASSWORD`, `PIXELFLUX_WAYLAND`, GPU
options, etc.), plus:

| Variable                 | Default | Purpose                                                  |
|--------------------------|---------|----------------------------------------------------------|
| `LOSSLESSCUT_EXTRA_ARGS` | (empty) | Extra Electron flags, split on spaces (e.g. `--disable-gpu`) |
| `SELKIES_UI_SIDEBAR_SHOW_APPS` | `false` | Show the app launcher section in the Selkies sidebar |
| `SELKIES_ENCODER` | `h265enc,h264enc,vp8enc,vp9enc,av1enc,jpeg` | Stream encoders; the first is the default. Browsers that cannot decode H.265 fall back down the list |
| `SELKIES_FILE_TRANSFERS` | `none` | Browser file upload/download. The server rejects both with HTTP 403 |
| `SELKIES_WEBCAM_ENABLED` | `false\|locked` | Webcam forwarding; locked so the browser cannot turn it on |
| `SELKIES_MICROPHONE_ENABLED` | `false\|locked` | Microphone forwarding; locked so the browser cannot turn it on |

Gamepads and the webcam are off by default (`NO_GAMEPAD=true`,
`NO_WEBCAM=true`, plus the matching Selkies settings). The base image only
checks whether `NO_GAMEPAD` and `NO_WEBCAM` are set, so setting them to `false`
has no effect.

File transfer, webcam and microphone are set in the image, not in the browser.
To turn one back on, override the variable at `docker run` (for example
`-e SELKIES_FILE_TRANSFERS=upload,download`).

The start command and menu are copied to `/config/.config/openbox/` (or
`labwc/` in Wayland mode) on first run only. Delete those files to pick up new
defaults after an image update.

## License

MIT ([LICENSE](LICENSE)). Bundled LosslessCut and ffmpeg are GPL.