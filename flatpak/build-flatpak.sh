#!/bin/bash
# Build the Flatpak for the published edition.
#
# The application source is not in this repository — the repository carries the patch series, and
# PKGBUILD builds the tree by extracting the upstream release tarball and applying each patch in
# `prepare()` order. A Flatpak has to see the same tree, so this script builds it the same way and then
# hands flatpak-builder a directory source that already contains the patched source and the packaging
# files. One series, two packagers, no second copy of the truth.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$HOME/flatpak-build}"
SRC="$WORK/src"
BUILD="$WORK/build"
REPO_DIR="$WORK/repo"
STATE="$WORK/state"

PKGVER=$(sed -n 's/^pkgver=//p' "$REPO/PKGBUILD")
# The series is written against the *upstream* release, so that is what gets patched. The custom tarball
# in src/ is this machine's prepared tree and cannot be the base for a patch that expects upstream.
TARBALL="$REPO/src/QuixiDesk-${PKGVER}.tar.gz"
if [ ! -f "$TARBALL" ]; then
  echo "== downloading the upstream release"
  curl -sSL --speed-limit 2048 --speed-time 45 --retry 3 --retry-all-errors \
    -o "$TARBALL" "https://github.com/QuixiAI/QuixiDesk/archive/refs/tags/v${PKGVER}.tar.gz"
fi
# A prepared tree beside the tarball (src/QuixiDesk-<ver>) is the tree the application is actually built
# from here. Use it when it exists: the Flatpak should package what runs, and the series currently needs
# re-baselining before it can rebuild that tree from scratch. When it is absent, fall through to the
# tarball-plus-series path below.
# --- sign --------------------------------------------------------------------
# Both build paths end here, so it is a function rather than a trailing step. The prepared-tree path
# used to `exit 0` right after build-bundle and published an UNSIGNED repository while reporting
# success — the quiet failure the rest of this comment is about.
#
# flatpak-builder writes an UNSIGNED repository. Publishing one unsigned is the quiet failure this step
# exists to prevent: the ref file, `flatpak remote-ls` and the bundle all look right, and every client
# that actually verifies gets "BAD signature" and refuses to load the summary.
#
# The key lives in its own keyring, not the default one, so GNUPGHOME is set here rather than relied on.
sign_repo() {
  SIGN_KEY="${QUIXI_FLATPAK_KEY:-BEA4F4E734ECF3EC}"
  SIGN_HOME="${QUIXI_FLATPAK_GNUPGHOME:-$HOME/.config/quixidesk-flatpak/gnupg}"
  if [ -d "$SIGN_HOME" ]; then
    echo "== signing the repository with $SIGN_KEY"
    GNUPGHOME="$SIGN_HOME" flatpak build-update-repo \
      --gpg-sign="$SIGN_KEY" \
      --generate-static-deltas \
      "$REPO_DIR"
  else
    echo "== NOT SIGNED: no keyring at $SIGN_HOME" >&2
    echo "   A published repo must be signed. Set QUIXI_FLATPAK_GNUPGHOME or create that keyring." >&2
  fi
}

PREPARED="$REPO/src/QuixiDesk-${PKGVER}"
if [ -d "$PREPARED" ]; then
  echo "== using the prepared tree at $PREPARED"
  rm -rf "$SRC"; mkdir -p "$SRC"
  cp -a "$PREPARED" "$SRC/"
  TREE="$SRC/QuixiDesk-${PKGVER}"
  cp -a "$REPO/flatpak" "$TREE/flatpak"
  # The vendored registry is what makes the build work with no network inside the sandbox. If the tree does
# not have one — a fresh clone, a clean checkout — make it here, once, from the lockfile. That is the
# difference between "builds on the machine that made it" and "builds from the repository".
if [ ! -d "$TREE/vendor" ]; then
  echo "== vendoring the crate registry"
  ( cd "$TREE" && cargo vendor --locked vendor >/dev/null )
fi

# The manifest packages a prebuilt binary rather than compiling inside the sandbox — the Rust SDK
# extension does not fit the Flatpak build container, and a packager should not be able to fail on a
# toolchain. Compile here, hand it in.
if [ ! -x "$TREE/prebuilt/QuixiDesk" ]; then
  echo "== building the binary"
  ( cd "$TREE" && cargo build --release -p quixi-app )
  mkdir -p "$TREE/prebuilt"
  cp "$TREE/target/release/QuixiDesk" "$TREE/prebuilt/QuixiDesk"
fi

echo "== staging the source archive"
# A dir source does not carry dotfiles, and a vendored crate without .cargo-checksum.json cannot build.
# So the tree is archived and the manifest is staged beside it with an archive source.
STAGE="$WORK/stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
# The prepared tree is the tree the application runs from, and something may be writing to it while we
# read (a build, an editor). So the archive is made from a clean copy, with the local build artifacts and
# the repository left out — target/ alone is 5.8 GB and the sandbox builds its own.
SRCCOPY="$WORK/archive-src"
rm -rf "$SRCCOPY"; mkdir -p "$SRCCOPY"
# Anchored excludes: an unanchored 'target/' also strips vendor/cc/src/target, and a vendored crate
# missing a file will not build. Only the tree's own build directory goes.
rsync -a --exclude '/target/' --exclude '/.git/' "$TREE/" "$SRCCOPY/QuixiDesk-${PKGVER}/"

tar czf "$STAGE/quixidesk-src.tar.gz" --warning=no-file-changed \
  -C "$SRCCOPY" "QuixiDesk-${PKGVER}" || [ $? -eq 1 ]

# The manifest is staged beside the archive with an archive source instead of a dir source.
python3 - "$REPO/flatpak/io.github.volkdude85.quixidesk.yml" "$STAGE/manifest.yml" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()
# Everything from "sources:" to the end of the module is replaced with the staged archive. Matching the
# block rather than one spelled-out path, because the source line has changed shape more than once and a
# stale pattern is how this failed the last two times.
text = re.sub(r"(?ms)^    sources:.*\Z",
              "    sources:\n      - type: archive\n        path: quixidesk-src.tar.gz\n",
              text, count=1)
open(dst, "w").write(text)
PY

echo "== building with flatpak-builder"
rm -rf "$BUILD" "$REPO_DIR"
# --disable-cache, and it is not a performance choice. The source archive is staged at the same path
# with the same name on every build, so a cache lookup hit and packaged the PREVIOUS export while the
# new app.js sat in the archive beside it. The build reported success, the bundle looked right, and the
# published commit carried the old file — caught only by checking a file out of the exported commit.
flatpak-builder --user --disable-cache --state-dir="$STATE" --force-clean --repo="$REPO_DIR" \
  "$BUILD" "$STAGE/manifest.yml"
# Check the export before it is ever signed or published: the file that was just built has to be the
# file in the commit, or nothing downstream of this line means anything.
if [ -n "${VERIFY_FILE:-}" ] && [ -n "${VERIFY_TEXT:-}" ]; then
  COMMIT=$(cat "$REPO_DIR/refs/heads/app/io.github.volkdude85.quixidesk/x86_64/master")
  CHK="$WORK/verify-out"; rm -rf "$CHK"
  ostree checkout --repo="$REPO_DIR" --user-mode "$COMMIT" "$CHK" >/dev/null 2>&1 || true
  if [ -n "$(grep -rl -- "$VERIFY_TEXT" "$CHK" 2>/dev/null | grep -- "$VERIFY_FILE" | head -1)" ]; then
    echo "  ✓ the exported commit carries $VERIFY_TEXT in $VERIFY_FILE"
  else
    echo "  ✗ the exported commit does NOT carry $VERIFY_TEXT in $VERIFY_FILE — stale cache, not publishing" >&2
    exit 1
  fi
fi
BUNDLE="$WORK/QuixiDesk.flatpak"
flatpak build-bundle "$REPO_DIR" "$BUNDLE" io.github.volkdude85.quixidesk
ls -la "$BUNDLE"

sign_repo
exit 0
fi

# and it has to be the checksum the PKGBUILD pins, or the build is not reproducible
WANT=$(grep -oE "[0-9a-f]{64}" "$REPO/PKGBUILD" | while read -r h; do
        [ "$h" = "$(sha256sum "$TARBALL" | cut -d' ' -f1)" ] && echo "$h" && break
      done | head -1)
[ -n "$WANT" ] || { echo "the tarball does not match any checksum in PKGBUILD" >&2; exit 1; }

echo "== extracting $(basename "$TARBALL")"
rm -rf "$SRC"
mkdir -p "$SRC"
tar xzf "$TARBALL" -C "$SRC"
TREE=$(find "$SRC" -maxdepth 1 -mindepth 1 -type d | head -1)
[ -d "$TREE" ] || { echo "tarball did not contain a directory" >&2; exit 1; }

echo "== applying the series in prepare() order"
cd "$TREE"
for p in $(sed -n '/^prepare()/,/^build()/p' "$REPO/PKGBUILD" \
             | grep -oE '[0-9]{4}-[a-z0-9-]+\.patch' | awk '!seen[$0]++'); do
  path=$(find "$REPO/patches" -name "$p" | head -1)
  [ -n "$path" ] || { echo "missing patch: $p" >&2; exit 1; }
  if patch -Np1 -s -i "$path" >/dev/null 2>&1; then
    :
  elif [ -z "$(find . -name '*.rej' | head -1)" ]; then
    # Its content is already in the tree from an earlier patch in the series: a no-op, not a failure.
    echo "   already applied: $p"
  else
    echo "patch failed: $p" >&2
    find . -name '*.rej' | head -3 >&2
    exit 1
  fi
done
rm -f CREDITS resources/ui/*.rej resources/ui/*.orig 2>/dev/null || true

echo "== adding the packaging files"
cp -a "$REPO/flatpak" "$TREE/flatpak"

echo "== building with flatpak-builder"
mkdir -p "$WORK"
rm -rf "$BUILD" "$REPO_DIR"
flatpak-builder --user --disable-cache \
  --state-dir="$STATE" \
  --force-clean \
  --repo="$REPO_DIR" \
  "$BUILD" "$TREE/flatpak/io.github.volkdude85.quixidesk.yml"

BUNDLE="$WORK/QuixiDesk.flatpak"
echo "== exporting $BUNDLE"
flatpak build-bundle "$REPO_DIR" "$BUNDLE" io.github.volkdude85.quixidesk
ls -la "$BUNDLE"

sign_repo
