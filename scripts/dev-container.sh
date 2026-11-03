#!/usr/bin/env bash
# A container to build QuixiDesk in, for machines you would rather not install a toolchain on.
#
#   ./scripts/dev-container.sh create    # build the container image (or container, on distrobox)
#   ./scripts/dev-container.sh prepare   # turn this repository's patch series into a source tree
#   ./scripts/dev-container.sh build     # build the release binary from that tree
#   ./scripts/dev-container.sh run       # build, then launch the app from inside the container
#   ./scripts/dev-container.sh shell     # a shell inside it, in the repo
#
# The point of `prepare`: this repository carries the series, not the application source. So the
# container fetches the upstream tag the PKGBUILD names, applies every patch in `prepare()` order, and
# leaves the tree at src/QuixiDesk-<version>/ inside the mounted repo. `build` then compiles that tree
# with the toolchain in the image. Edit a patch here, run `prepare` again, and you are building your
# change — that is the loop.
#
# The image lives in your user's container storage, never in the OS image, so a system update does not
# wipe it. Your working tree is mounted at /work — the same files you edit outside, visible inside —
# so nothing is copied and nothing drifts.
#
# This is the developer route, not the user route. Users get the Flatpak or the package.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${QUIXI_DEV_CONTAINER:-quixi-dev}"
IMAGE="${QUIXI_DEV_IMAGE:-archlinux:latest}"
TAG="${QUIXI_DEV_TAG:-quixi-dev:latest}"
ACTION="${1:-create}"

say() { printf '\n== %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if have distrobox; then
  BACKEND=distrobox
elif have podman; then
  BACKEND=podman
elif have docker; then
  BACKEND=docker
else
  cat >&2 <<'EOF'
No container runtime found. Install one of:

  distrobox   the easiest on an immutable system, and it is in most distros' repos
  podman       rootless, in the Arch and Fedora repos
  docker       if you already run it

On SteamOS, distrobox is a Flatpak in the Discover store.
EOF
  exit 1
fi

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

# The hard set: the app links webkit2gtk and GTK, and the build needs rust, pkg-config and a linker.
PKGLIST="base-devel rust pkgconf clang openssl gtk3 webkit2gtk-4.1 libsoup3 \
hicolor-icon-theme desktop-file-utils git nodejs npm"

case "$ACTION" in
  create)
    say "container: $CONTAINER  image: $IMAGE  backend: $BACKEND"
    case "$BACKEND" in
      distrobox)
        if distrobox list --no-color 2>/dev/null | awk '{print $2}' | grep -qx "$CONTAINER"; then
          echo "container already exists — reusing"
        else
          distrobox create --name "$CONTAINER" --image "$IMAGE" --volume "$REPO:/work" --yes
        fi
        distrobox enter "$CONTAINER" -- sudo pacman -Syu --noconfirm --needed $PKGLIST
        ;;
      podman|docker)
        # Bake the toolchain into an image once. A one-shot container would throw it away.
        tmp="$(mktemp -d)"
        cat > "$tmp/Dockerfile" <<EOF
FROM $IMAGE
RUN pacman -Syu --noconfirm --needed $PKGLIST \\
 && pacman -Scc --noconfirm
WORKDIR /work
EOF
        "$BACKEND" build -t "$TAG" "$tmp"
        rm -rf "$tmp"
        ;;
    esac
    say "done"
    echo "Build with:  ./scripts/dev-container.sh build"
    ;;

  prepare)
    say "preparing the source tree from the series ($BACKEND)"
    # Everything runs inside the container so the only toolchain needed on the host is a container
    # runtime. The series is applied in exactly the order PKGBUILD's prepare() names, which is the
    # order that ships.
    PREP=$(cat <<'EOS'
set -euo pipefail
cd /work
pkgver=$(sed -n 's/^pkgver=//p' PKGBUILD | head -1)
[ -n "$pkgver" ] || { echo "no pkgver in PKGBUILD" >&2; exit 1; }
mkdir -p src
cd src
tarball="QuixiDesk-${pkgver}.tar.gz"
[ -f "$tarball" ] || curl -fsSL --retry 3 --retry-all-errors \
  -o "$tarball" "https://github.com/QuixiAI/QuixiDesk/archive/refs/tags/v${pkgver}.tar.gz"
rm -rf "QuixiDesk-${pkgver}"
tar xzf "$tarball"
cd "QuixiDesk-${pkgver}"
n=0
for p in $(sed -n '/^prepare()/,/^build()/p' /work/PKGBUILD \
             | grep -oE '[0-9]{4}-[a-z0-9-]+\.patch' | awk '!seen[$0]++'); do
  src_patch=$(find /work/patches -name "$p" | head -1)
  [ -n "$src_patch" ] || { echo "missing patch: $p" >&2; exit 1; }
  patch -Np1 -s -i "$src_patch"
  n=$((n+1))
done
echo "applied $n patches to QuixiDesk-${pkgver}"
EOS
)
    case "$BACKEND" in
      distrobox) distrobox enter "$CONTAINER" -- bash -lc "$PREP" ;;
      *)         "$BACKEND" run --rm -it -v "$REPO:/work" -w /work "$TAG" bash -lc "$PREP" ;;
    esac
    ;;

  build|run)
    cmd=$(cat <<'EOS'
set -euo pipefail
cd /work
pkgver=$(sed -n 's/^pkgver=//p' PKGBUILD | head -1)
if [ -d "src/QuixiDesk-${pkgver}" ]; then
  cd "src/QuixiDesk-${pkgver}"
  echo "building src/QuixiDesk-${pkgver} (the prepared tree)"
else
  echo "building the working tree (no prepared tree — run: $0 prepare)"
fi
cargo build --release -p quixi-app
echo "binary: $(pwd)/target/release/QuixiDesk"
EOS
)
    if [ "$ACTION" = run ]; then
      cmd="$cmd
QUIXI_RESOURCES_DIR=\$(pwd)/resources ./target/release/QuixiDesk"
    fi
    say "building inside $CONTAINER ($BACKEND)"
    case "$BACKEND" in
      distrobox) distrobox enter "$CONTAINER" -- bash -lc "$cmd" ;;
      *)         "$BACKEND" run --rm -it -v "$REPO:/work" -w /work "$TAG" bash -lc "$cmd" ;;
    esac
    ;;

  shell)
    say "shell in $CONTAINER, /work is $REPO"
    case "$BACKEND" in
      distrobox) distrobox enter "$CONTAINER" -- bash -lc 'cd /work && exec bash' ;;
      *)         "$BACKEND" run --rm -it -v "$REPO:/work" -w /work "$TAG" bash ;;
    esac
    ;;

  *) usage; exit 1 ;;
esac
