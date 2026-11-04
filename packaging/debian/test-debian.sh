#!/bin/bash
# Test the Debian packaging path end to end, inside a real Debian container.
#   ./test-debian.sh [suite]     suite defaults to bookworm (Debian 12); trixie and ubuntu:24.04 work too
set -uo pipefail
SUITE=${1:-bookworm}
NAME=quixidesk-debtest
IMG=${SUITE}
case "$SUITE" in
  bookworm|trixie|bullseye) IMG="docker.io/library/debian:$SUITE" ;;
  ubuntu*|noble|jammy)      IMG="docker.io/library/ubuntu:${SUITE#ubuntu}" ;;
esac

docker rm -f "$NAME" >/dev/null 2>&1 || true
echo "== $IMG"
docker run -d --name "$NAME" -w /work "$IMG" sleep infinity >/dev/null || exit 1

docker exec "$NAME" bash -lc 'apt-get update -qq && apt-get install -y -qq --no-install-recommends \
  ca-certificates curl git sudo build-essential pkg-config dpkg-dev xz-utils \
  cargo rustc librsvg2-bin libgtk-3-dev libwebkit2gtk-4.1-dev libsoup-3.0-dev \
  libssl-dev libpulse-dev libdbus-1-dev >/tmp/apt.log 2>&1' || { echo "apt failed"; docker exec "$NAME" tail -20 /tmp/apt.log; exit 1; }
echo "== deps installed"

docker cp "$(cd "$(dirname "$0")/../.." && pwd)" "$NAME":/repo >/dev/null || exit 1
docker exec "$NAME" bash -lc 'cd /repo/packaging/debian && ./build-deb.sh' 2>&1 | tail -25
rc=${PIPESTATUS[0]}
echo "== build rc=$rc"
docker exec "$NAME" bash -lc 'ls -la /repo/packaging/debian/dist/ 2>/dev/null'
