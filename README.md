
# simlive-cloudflare

A tiny Dockerized pipeline that streams a folder of video files as a continuous **simulated live** channel into a single **Cloudflare Stream Live Input**. No OBS required.

## What it does

- Walks a directory of files (e.g., `.mp4`, `.mov`, `.mkv`), builds an FFmpeg concat playlist, and loops through it forever.
- Pushes the output to your **Cloudflare Stream Live Input** via **RTMPS** (default). SRT can be added later.
- Ships as a minimal Docker image + `docker-compose.yml` for easy deployment on a Droplet (DigitalOcean), home server, or any Docker host.
- Optional **cloud-init** lets you go from Droplet creation → streaming automatically.

> Cloudflare Stream auto-records live inputs to VOD and can simulcast to other platforms from the same input.

---

## Quick start (local or on any Docker host)

1) **Create a Live Input** in Cloudflare Stream (Dashboard → Stream → Live inputs → Create). Copy the stream key from the RTMPS endpoint.
2) Put some videos into `./videos/` (or mount a different path in `docker-compose.yml`).
3) Copy `.env.example` to `.env` and set:
   ```bash
   CF_STREAM_KEY=YOUR_CLOUDFLARE_LIVE_INPUT_KEY
   ```
4) Build and run:
   ```bash
   docker compose up -d --build
   ```
5) Watch your Live Input in the Cloudflare dashboard.

### Environment variables

| Variable        | Default | Description |
|----------------|---------|-------------|
| `SRC_DIR`      | `/videos` | Where the container reads your files. |
| `CF_PROTOCOL`  | `rtmps` | Only RTMPS is wired by default in this repo. |
| `CF_HOST`      | `live.cloudflare.com` | Cloudflare ingest host. |
| `CF_PORT`      | `443` | RTMPS port. |
| `CF_PATH`      | `/live` | Ingest path prefix. |
| `CF_STREAM_KEY`| *(none)* | **Required**. Appended to RTMPS URL. |
| `VIDEO_BITRATE`| `4500k` | Target video bitrate. |
| `AUDIO_BITRATE`| `160k` | Target audio bitrate. |
| `GOP_SIZE`     | `60` | Keyframe distance (e.g., 60 at 30fps). |
| `FRAMERATE`    | `30` | Output frame rate. |

> Tip: If your source files already match your target codec/params and you want to avoid re-encoding, you can experiment with `-c copy`. Re-encoding is safer for live stability across mixed files.

---

## DigitalOcean: One-click-ish with the Docker 1-Click Droplet

1) Create a **Docker 1-Click** Droplet in DigitalOcean.
2) (Recommended) Attach a **Block Storage Volume** and mount it at `/mnt/videos`.
3) SSH in and deploy:
   ```bash
   sudo mkdir -p /mnt/videos
   # upload files into /mnt/videos via sftp/rsync
   git clone https://example.com/your/simlive-cloudflare.git /opt/simlive
   cd /opt/simlive
   cp .env.example .env && nano .env   # paste your CF_STREAM_KEY
   sed -i 's#./videos:/videos:ro#/mnt/videos:/videos:ro#' docker-compose.yml
   docker compose up -d --build
   ```

### Fully hands-off with cloud-init (User Data)

When creating the Droplet, paste the contents of `cloud-init/user-data.yaml` in **User Data**. It will clone the repo, write `.env`, mount `/mnt/videos` (create if not present), and bring the stack up automatically on first boot. After boot, check `/var/log/cloud-init-output.log`.

> Replace placeholders in the cloud-init with your Git URL and `CF_STREAM_KEY`.

---

## App Platform (optional, small/remote libraries only)

DigitalOcean App Platform has limited/ephemeral filesystem. If you bake a small set of assets into the image or fetch a remote playlist (e.g., from object storage), you can deploy using `.do/app.yaml`. For large local libraries, prefer Droplets + Volumes.

---

## Files

- `Dockerfile` – minimal Alpine + FFmpeg build.
- `simlive.sh` – builds a playlist and loops FFmpeg forever.
- `docker-compose.yml` – production defaults and volume mapping.
- `.env.example` – environment template.
- `cloud-init/user-data.yaml` – paste into DO Droplet User Data to auto-deploy.
- `.do/app.yaml` – optional App Platform spec (for small/remote-asset setups).
- `LICENSE` – MIT.
- `.gitignore` – ignores typical clutter and local `videos/`.

---

## Troubleshooting

- **No output in dashboard** – Check logs:
  ```bash
  docker logs -f simlive
  ```
- **Codec errors** – Mixed codecs/containers can be normalized by re-encode (the default settings). If pushing huge bitrates over weak links, drop `VIDEO_BITRATE`.
- **Playlist empty** – Ensure your volume mapping is correct and files have readable extensions.
- **Keyframe cadence** – Keep a fixed GOP (e.g., 2s @ 30fps → `GOP_SIZE=60`).

---

## License

MIT


---

## Deploy to DigitalOcean (App Platform)

This repo includes a **Deploy to DO** button. It sets up a **Worker** on App Platform that runs the same Docker image and streams to your Cloudflare Live Input. Because App Platform's filesystem is **ephemeral** and doesn't support volumes, this path expects a **remote playlist** (e.g., a public file hosted on DigitalOcean Spaces or any HTTP(S) URL).

1) Create a public text file that lists your media in **ffconcat** format (supports URLs):
   ```
   ffconcat version 1.0
   file https://your-space.nyc3.cdn.digitaloceanspaces.com/channel/intro.mp4
   file https://your-space.nyc3.cdn.digitaloceanspaces.com/channel/show1_part1.mp4
   file https://your-space.nyc3.cdn.digitaloceanspaces.com/channel/show1_part2.mp4
   ```
   > Files must be publicly fetchable by the worker; use a CDN endpoint for Spaces, or make objects public.

2) Click the button below and fill in the prompts for `CF_STREAM_KEY` (secret) and `REMOTE_PLAYLIST_URL` (the URL you created above).

> **Note:** Update the link below with your actual repo path (owner/name/branch) when you publish to GitHub.

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/dblodorn/simlive-cloudflare/tree/main)

References: App Platform storage is ephemeral and does not support persistent volumes; use Spaces or another remote source for media.
