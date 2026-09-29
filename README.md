# docker-losslesscut

[LosslessCut](https://github.com/mifi/lossless-cut) in a container, built on
[jlesage/baseimage-gui](https://github.com/jlesage/docker-baseimage-gui).

Runs the latest LosslessCut with a separately pinned ffmpeg (default **n8.1**),
since the ffmpeg LosslessCut bundles (8.0) has a regression for us. Both are
build args. `amd64` and `arm64` supported.

## Build

```sh
docker build -t ghcr.io/avcabal/losslesscut:26.09.1 .

# override versions:
docker build --build-arg FFMPEG_VERSION=9.0 -t ghcr.io/avcabal/losslesscut:custom .
```

| Build arg             | Default  | Purpose                          |
|-----------------------|----------|----------------------------------|
| `LOSSLESSCUT_VERSION` | `3.69.0` | LosslessCut release              |
| `FFMPEG_VERSION`      | `8.1`    | BtbN ffmpeg branch (e.g. `9.0`)  |

## Run

```sh
docker run -d \
  --name losslesscut \
  -p 5800:5800 \
  -e USER_ID=1000 -e GROUP_ID=1000 \
  -v losslesscut-config:/config \
  -v /path/to/media:/storage \
  --shm-size=1g \
  ghcr.io/avcabal/losslesscut:26.09.1
```

Open <http://localhost:5800>. Images are published to
`ghcr.io/avcabal/losslesscut` on tag (see `.github/workflows/build-image.yml`).

## Ports

| Port | Purpose        |
|------|----------------|
| 5800 | Web UI (noVNC) |
| 5900 | VNC (optional) |

## Volumes

| Path       | Purpose    |
|------------|------------|
| `/config`  | App config |
| `/storage` | Your media |

## Environment variables

Standard [baseimage-gui variables](https://github.com/jlesage/docker-baseimage-gui#environment-variables)
apply, plus:

| Variable                 | Default | Purpose                                     |
|--------------------------|---------|---------------------------------------------|
| `LOSSLESSCUT_EXTRA_ARGS` | (empty) | Extra Electron flags (e.g. `--disable-gpu`) |
| `WEB_AUDIO`              | `1`     | Browser audio; set `0` to disable           |

## License

MIT ([LICENSE](LICENSE)). Bundled LosslessCut and ffmpeg are GPL.
