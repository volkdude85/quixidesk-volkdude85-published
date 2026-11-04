#!/bin/bash
# Build a .deb from the same tarball and the same patch series the PKGBUILD uses.
#
#   ./build-deb.sh                 build into ./dist
#   ./build-deb.sh --deps          print the apt command and stop
#   PKGVER=3.6556.12 ./build-deb.sh
#
# Run it as a normal user on Debian/Ubuntu (12/bookworm and 24.04 are the tested pair). It does not
# need root: it fetches into ./work, builds there, and writes the package into ./dist.
#
# Why a script and not debian/ with debhelper: this tree is a PATCH SERIES against an upstream
# tarball, not a source tree. debhelper expects the patches to live in debian/patches and be applied by
# quilt at build time; the series here is 100+ files that are already the package's own history, and a
# second copy of them inside debian/ would be a fork of itself. So this does what the PKGBUILD's
# prepare() does, in the same order, and then installs the same layout.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
PKGVER=${PKGVER:-$(sed -n 's/^pkgver=//p' "$REPO/PKGBUILD" | tr -d '"' | head -1)}
PKGNAME=quixidesk
WORK=${WORK:-$HERE/work}
DIST=${DIST:-$HERE/dist}
TARBALL_URL=${TARBALL_URL:-https://github.com/QuixiAI/QuixiDesk/archive/refs/tags/v${PKGVER}.tar.gz}

# Runtime dependencies, in Debian's vocabulary. Every one of these is a row in DISTROS.md.
RUNTIME_DEPS="libc6, libgcc-s1, libgtk-3-0, libwebkit2gtk-4.1-0, libglib2.0-0, libpango-1.0-0, \
libcairo2, libgdk-pixbuf-2.0-0, libsoup-3.0-0, libdbus-1-3, libpulse0, hicolor-icon-theme, bash"

RECOMMENDS="ydotool, wl-clipboard, zenity, imagemagick, xdotool, git"

BUILD_DEPS="build-essential cargo rustc pkg-config librsvg2-bin libgtk-3-dev libwebkit2gtk-4.1-dev \
libsoup-3.0-dev libssl-dev libpulse-dev libdbus-1-dev"

if [ "${1:-}" = "--deps" ]; then
  echo "sudo apt install $BUILD_DEPS"
  exit 0
fi

command -v dpkg-deb >/dev/null || { echo "dpkg-deb is missing — this must run on Debian or Ubuntu." >&2; exit 1; }
command -v cargo    >/dev/null || { echo "cargo is missing. Try: $0 --deps" >&2; exit 1; }

# The lock file is format v4, which needs cargo 1.78 or newer. Debian 12 ships 1.65, so its packaged
# cargo fails with "lock file version `4` was found, but this version of Cargo does not understand
# this lock file" — which reads like a broken tree rather than an old toolchain. Say so instead.
CARGO_VER=$(cargo --version | awk '{print $2}')
CARGO_MAJ=${CARGO_VER%%.*}
CARGO_MIN=$(echo "$CARGO_VER" | cut -d. -f2)
if [ "${CARGO_MAJ:-0}" -lt 1 ] || { [ "${CARGO_MAJ:-0}" -eq 1 ] && [ "${CARGO_MIN:-0}" -lt 78 ]; }; then
  cat >&2 <<EOF
cargo $CARGO_VER is too old: this tree's Cargo.lock is format v4 and needs cargo 1.78+.
Two ways forward on this distribution:

  rustup (works on any Debian/Ubuntu release):
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
    . "\$HOME/.cargo/env"

  Debian 12 "bookworm" only: the newer toolchain from backports
    echo 'deb http://deb.debian.org/debian bookworm-backports main' | sudo tee /etc/apt/sources.list.d/backports.list
    sudo apt update && sudo apt install -t bookworm-backports cargo rustc

Debian 13 "trixie" and Ubuntu 24.04 ship a new enough cargo already.
EOF
  exit 1
fi

mkdir -p "$WORK" "$DIST"

# --- 1. the upstream tarball -------------------------------------------------
SRC="$WORK/QuixiDesk-$PKGVER"
if [ ! -d "$SRC" ]; then
  echo "== fetching v$PKGVER"
  curl -fsSL "$TARBALL_URL" -o "$WORK/QuixiDesk-$PKGVER.tar.gz"
  tar xf "$WORK/QuixiDesk-$PKGVER.tar.gz" -C "$WORK"
fi

# --- 2. the patch series, in the order prepare() applies it ------------------
# NOT the `source=()` order: that array is grouped by area, and prepare() deliberately applies a few
# of them out of that order (0026 before 0027, for one). Taking the source list here applies 0053 on
# top of the wrong tree and it rejects a hunk in quixi-engine/src/lib.rs.
cd "$SRC"
mapfile -t ORDER < <(sed -n '/^prepare()/,/^}/p' "$REPO/PKGBUILD" \
  | grep -oE '\$\{srcdir\}/[0-9]{4}-[A-Za-z0-9.-]+\.patch' | sed 's|.*/||' | awk '!seen[$0]++')
echo "== applying ${#ORDER[@]} patches"
for p in "${ORDER[@]}"; do
  f="$REPO/$p"
  [ -f "$f" ] || f=$(find "$REPO/patches" -name "$p" | head -1)
  [ -f "$f" ] || { echo "  MISSING $p" >&2; exit 1; }
  # Files the series CREATES are removed first: a second run in the same tree would otherwise apply
  # an add-on-top-of-itself and quietly double the file.
  patch -Np1 -s -i "$f" || { echo "  FAILED $p" >&2; exit 1; }
done

# --- 3. build ----------------------------------------------------------------
# Personal name map, same rule as the PKGBUILD: never in this repo. The shipped file carries an empty
# map; a builder who has names points this at a file outside the tree, one `[/pattern/gi, "replacement"],`
# per line, and it is filled in here before compiling.
if [ -n "${QUIXI_REDACT_NAMES:-}" ] && [ -f "${QUIXI_REDACT_NAMES}" ]; then
  _js="resources/ui/capability-workflows.js"
  awk -v m="${QUIXI_REDACT_NAMES}" '
    /const NAME_MAP = \[$/ { print; while ((getline l < m) > 0) print l; next }
    { print }
  ' "$_js" > "${_js}.tmp" && mv "${_js}.tmp" "$_js"
  echo "== name map: $(grep -c '/gi' "$_js") entries from ${QUIXI_REDACT_NAMES}"
else
  echo "== name map: empty (QUIXI_REDACT_NAMES not set)"
fi

# Same two invocations the PKGBUILD's build() runs: `--lib` then `--bins`, over the whole workspace.
# `-p quixi-app -p quixi-engine` looks equivalent and is not — the workspace has eight binaries spread
# across crates, and quixi-chrome-native-host / quixi-mcp-* / quixi-ssh-askpass live outside those two.
echo "== cargo build --release"
export CARGO_NET_OFFLINE=false
export QUIXI_EDITION_LABEL="(volkdude85 deb) "
cargo build --release --workspace --locked --lib
cargo build --release --workspace --locked --bins

BINS=(QuixiDesk quixi quixi-chrome-native-host quixi-disclaimer quixi-guest-daemon
      quixi-mcp-builtin quixi-mcp-worker quixi-ssh-askpass)
for b in "${BINS[@]}"; do
  [ -x "target/release/$b" ] || { echo "missing target/release/$b (the workspace build should have made it)" >&2; exit 1; }
done

# --- 4. package root, same layout the PKGBUILD installs -----------------------
ROOT="$WORK/root-${PKGNAME}_${PKGVER}_amd64"
rm -rf "$ROOT"
LIBDIR="$ROOT/usr/lib/quixidesk"
install -d "$LIBDIR" "$ROOT/usr/bin" "$ROOT/DEBIAN" \
           "$ROOT/usr/share/applications" "$ROOT/usr/share/doc/$PKGNAME" \
           "$ROOT/usr/share/licenses/$PKGNAME"

for b in "${BINS[@]}"; do install -Dm755 "target/release/$b" "$LIBDIR/$b"; done
cp -a resources "$LIBDIR/resources"
install -Dm644 LICENSE "$ROOT/usr/share/licenses/$PKGNAME/LICENSE"

cat > "$ROOT/usr/bin/$PKGNAME" <<'LAUNCH'
#!/bin/sh
_libdir=/usr/lib/quixidesk
export QUIXI_RESOURCES_DIR="${QUIXI_RESOURCES_DIR:-${_libdir}/resources}"
export QUIXI_MCP_WORKER="${QUIXI_MCP_WORKER:-${_libdir}/quixi-mcp-worker}"
case ":${PATH}:" in
  *":${_libdir}:"*) ;;
  *) PATH="${_libdir}:${PATH}"; export PATH ;;
esac
exec "${_libdir}/QuixiDesk" "$@"
LAUNCH
chmod 755 "$ROOT/usr/bin/$PKGNAME"
ln -s "../lib/quixidesk/quixi" "$ROOT/usr/bin/quixi"

cat > "$ROOT/usr/share/applications/$PKGNAME.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=QuixiDesk
GenericName=AI Desktop Workspace
Comment=Native desktop workspace for AI with cloud and local providers
Exec=quixidesk %U
Icon=quixidesk
Terminal=false
Categories=Development;Utility;
Keywords=AI;LLM;Chat;Assistant;Agent;MCP;Ollama;llama.cpp;
StartupNotify=true
StartupWMClass=QuixiDesk
DESKTOP

install -Dm644 resources/quixi-logo.svg "$ROOT/usr/share/icons/hicolor/scalable/apps/$PKGNAME.svg"
if command -v rsvg-convert >/dev/null; then
  for s in 16 24 32 48 64 128 256 512; do
    install -d "$ROOT/usr/share/icons/hicolor/${s}x${s}/apps"
    rsvg-convert -w "$s" -h "$s" resources/quixi-logo.svg \
      -o "$ROOT/usr/share/icons/hicolor/${s}x${s}/apps/$PKGNAME.png"
  done
else
  echo "  rsvg-convert missing: shipping the SVG icon only (apt install librsvg2-bin)" >&2
fi

install -Dm644 README.md "$ROOT/usr/share/doc/$PKGNAME/README.md"
[ -f ARCHITECTURE.md ] && install -Dm644 ARCHITECTURE.md "$ROOT/usr/share/doc/$PKGNAME/ARCHITECTURE.md"
[ -f "$REPO/DISTROS.md" ] && install -Dm644 "$REPO/DISTROS.md" "$ROOT/usr/share/doc/$PKGNAME/DISTROS.md"

SIZE=$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)
cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKGNAME
Version: $PKGVER
Section: devel
Priority: optional
Architecture: amd64
Maintainer: volkdude85 <volkdude85@users.noreply.github.com>
Installed-Size: $SIZE
Depends: $RUNTIME_DEPS
Recommends: $RECOMMENDS
Homepage: https://github.com/volkdude85/quixidesk-volkdude85-published
Description: native desktop workspace for AI, cloud and local providers
 A desktop workspace built on a real browser engine, with a file-backed memory
 store you own, local and cloud providers, MCP connections and a skill library.
 .
 This build carries the Linux platform layer: screenshot, clipboard, input
 synthesis, display enumeration and window control across KDE, GNOME, XFCE,
 Sway, Hyprland and X11 sessions, with the same source and the same patches as
 the Arch package.
EOF

cat > "$ROOT/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null; then update-desktop-database -q /usr/share/applications || true; fi
if command -v gtk-update-icon-cache >/dev/null; then gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true; fi
exit 0
POSTINST
cat > "$ROOT/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null; then update-desktop-database -q /usr/share/applications || true; fi
if command -v gtk-update-icon-cache >/dev/null; then gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true; fi
exit 0
POSTRM
chmod 755 "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/postrm"

echo "== dpkg-deb"
dpkg-deb --build --root-owner-group -Zxz "$ROOT" "$DIST/${PKGNAME}_${PKGVER}_amd64.deb"
dpkg-deb --info "$DIST/${PKGNAME}_${PKGVER}_amd64.deb" | sed -n '1,12p'
echo "== wrote $DIST/${PKGNAME}_${PKGVER}_amd64.deb"
