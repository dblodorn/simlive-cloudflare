
FROM alpine:3.20

# ffmpeg (with x264, aac) + bash + core utils
RUN apk add --no-cache ffmpeg bash coreutils findutils curl

# Simulated live script
COPY simlive.sh /usr/local/bin/simlive.sh
RUN chmod +x /usr/local/bin/simlive.sh

# Default envs (override at runtime)
ENV SRC_DIR=/videos
ENV CF_PROTOCOL=rtmps
ENV CF_HOST=live.cloudflare.com
ENV CF_PORT=443
ENV CF_PATH=/live
ENV CF_STREAM_KEY=""
ENV VIDEO_BITRATE=4500k
ENV AUDIO_BITRATE=160k
ENV GOP_SIZE=60
ENV FRAMERATE=30

WORKDIR /work
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD pidof ffmpeg || exit 1

CMD ["/usr/local/bin/simlive.sh"]
