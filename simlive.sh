
#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${SRC_DIR:-/videos}"
WORKDIR="${WORKDIR:-/work}"
PLAYLIST="$WORKDIR/playlist.txt"
REMOTE_PLAYLIST_URL="${REMOTE_PLAYLIST_URL:-}"

mkdir -p "$WORKDIR"

build_playlist() {
  echo "ffconcat version 1.0" > "$PLAYLIST"
  # include common video types; tweak if needed
  mapfile -t files < <(find "$SRC_DIR" -maxdepth 1 -type f \
    \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.m4v' \) | sort)
  for f in "${files[@]:-}"; do
    echo "file $f" >> "$PLAYLIST"
  done
  echo "[simlive] playlist rebuilt with ${#files[@]:-0} items"
}


# If REMOTE_PLAYLIST_URL is provided, fetch a remote ffconcat or list of files as the playlist.
if [[ -n "$REMOTE_PLAYLIST_URL" ]]; then
  echo "[simlive] Fetching remote playlist from $REMOTE_PLAYLIST_URL"
  if ! curl -fsSL "$REMOTE_PLAYLIST_URL" -o "$PLAYLIST"; then
    echo "[simlive] Failed to fetch remote playlist from $REMOTE_PLAYLIST_URL"
    exit 1
  fi
else
  build_playlist
fi

build_playlist

# Compose output URL
if [[ "${CF_PROTOCOL:-rtmps}" == "rtmps" ]]; then
  # rtmps://live.cloudflare.com:443/live/<STREAM_KEY>
  OUT_URL="${CF_PROTOCOL}://${CF_HOST}:${CF_PORT}${CF_PATH}/${CF_STREAM_KEY}"
elif [[ "${CF_PROTOCOL}" == "srt" ]]; then
  echo "SRT selected, but OUT_URL composition is not auto-implemented."
  echo "Please set OUT_URL explicitly with all SRT query params, or use RTMPS."
  exit 1
else
  echo "Unsupported CF_PROTOCOL: ${CF_PROTOCOL}"
  exit 1
fi

if [[ -z "${CF_STREAM_KEY:-}" ]]; then
  echo "CF_STREAM_KEY is required."
  exit 1
fi

while true; do
  ffmpeg -re     -f concat -safe 0 -i "$PLAYLIST"     -c:v libx264 -preset veryfast -profile:v high     -b:v "${VIDEO_BITRATE:-4500k}" -maxrate 6000k -bufsize 9000k     -r "${FRAMERATE:-30}" -g "${GOP_SIZE:-60}" -keyint_min "${GOP_SIZE:-60}" -sc_threshold 0     -c:a aac -b:a "${AUDIO_BITRATE:-160k}" -ar 48000 -ac 2     -f flv "$OUT_URL" || true

  echo "[simlive] FFmpeg exited. Rebuilding playlist and restarting in 5s..."
  build_playlist
  sleep 5
done
