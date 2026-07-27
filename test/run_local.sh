#!/bin/bash
# Boot the site in the real nginx image with the working tree mounted.
# Usage: test/run_local.sh [start|stop]
set -e

docker info >/dev/null 2>&1 || { echo "Docker is not running"; exit 1; }

NAME=zimzcore_local
PORT=8099
IMAGE=syddaps/zimzcore_index:latest
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-start}" in
  start)
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    docker run -d --name "$NAME" --platform linux/amd64 \
      -p "$PORT":80 -v "$ROOT":/site "$IMAGE" >/dev/null
    # Wait for nginx to answer rather than sleeping a fixed amount.
    for i in $(seq 1 30); do
      if curl -sS -o /dev/null "http://localhost:$PORT/up.html" 2>/dev/null; then
        echo "up on http://localhost:$PORT"; exit 0
      fi
      sleep 0.5
    done
    echo "container did not come up"; docker logs "$NAME" 2>&1 | tail -20; exit 1
    ;;
  stop)
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    echo "stopped"
    ;;
  *)
    echo "usage: $0 [start|stop]" >&2; exit 2
    ;;
esac
