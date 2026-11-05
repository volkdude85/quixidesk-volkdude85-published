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

# The identity everything is signed with, defined here because BOTH the commit (flatpak-builder) and the
# summary (build-update-repo) have to be signed with it. The key lives in its own keyring, not the default
# one, so GNUPGHOME is passed explicitly rather than relied on.
SIGN_KEY="${QUIXI_FLATPAK_KEY:-BEA4F4E734ECF3EC}"
SIGN_HOME="${QUIXI_FLATPAK_GNUPGHOME:-$HOME/.config/quixidesk-flatpak/gnupg}"
APP_ID="io.github.volkdude85.quixidesk"

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
# Two different objects need two different signatures, and only signing one of them is the trap:
#   * the COMMIT — signed by flatpak-builder via --gpg-sign (see both invocations below)
#   * the SUMMARY — signed by build-update-repo here
# A repo signed only at the summary level looks perfect to `remote-ls` and to the bundle, and every client
# that actually verifies dies with "GPG verification enabled, but no signatures found". That error cost a
# night: the failure is in the commit, and the gate at the end of sign_repo exists so it cannot recur unseen.
#
# The key lives in its own keyring, not the default one, so GNUPGHOME is passed explicitly rather than
# relied on.
sign_repo() {
  if [ ! -d "$SIGN_HOME" ]; then
    echo "== NOT SIGNED: no keyring at $SIGN_HOME" >&2
    echo "   A published repo must be signed. Set QUIXI_FLATPAK_GNUPGHOME or create that keyring." >&2
    exit 1
  fi
  echo "== signing the summary and generating deltas with $SIGN_KEY"
  # build-update-repo signs the SUMMARY only. Flatpak verifies each COMMIT's detached signature too, so a
  # summary-only repo fails on every client with "GPG verification enabled, but no signatures found" while
  # the summary itself verifies fine. The commits are signed where they are created — the --gpg-sign on
  # both flatpak-builder invocations below — and this step finishes the job.
  GNUPGHOME="$SIGN_HOME" flatpak build-update-repo \
    --gpg-sign="$SIGN_KEY" \
    --gpg-homedir="$SIGN_HOME" \
    --generate-static-deltas \
    "$REPO_DIR"

  # Gate, not a printout. The repo has to install the way a client sees it: a scratch user installation,
  # GPG verification on, keyring imported from the published key, --no-deps so no runtime is downloaded.
  # This is the exact step that failed for a whole night and reported success. If it fails, nothing
  # downstream may publish.
  echo "== verifying the repo as a verifying client sees it"
  local KEY="$WORK/sigcheck-key.asc" UD="$WORK/sigcheck-user"
  GNUPGHOME="$SIGN_HOME" gpg --armor --export "$SIGN_KEY" > "$KEY"
  rm -rf "$UD"; mkdir -p "$UD"
  if ( export FLATPAK_USER_DIR="$UD"
       flatpak remote-add --user --if-not-exists --gpg-import="$KEY" sigcheck "file://$REPO_DIR" >/dev/null
       flatpak install --user --noninteractive --no-deps -y sigcheck "$APP_ID" >/dev/null ); then
    echo "  ✓ the signed commit installs on a verifying client"
  else
    echo "  ✗ a verifying client CANNOT install from $REPO_DIR — refusing to call this built" >&2
    exit 1
  fi
  rm -rf "$UD"
}

# Which prepared tree. $WORK/src wins when it exists: that is the one this script stages and the one a
# fresh `makepkg --nobuild` produces, and it is the one whose prebuilt/ binary was just compiled. The
# repository's src/ tree is a leftover from an earlier run and its prebuilt binary does not get rebuilt by
# anything here, so preferring it silently shipped a three-patch-old UI beside a months-old binary — the
# export carried the new app.js because the *tree* was current, and the binary inside it was not. Say which
# tree is being packaged instead of picking one quietly.
if [ -d "$WORK/src/QuixiDesk-${PKGVER}" ]; then
  PREPARED="$WORK/src/QuixiDesk-${PKGVER}"
else
  PREPARED="$REPO/src/QuixiDesk-${PKGVER}"
fi
if [ -d "$PREPARED" ]; then
  if [ "$PREPARED" = "$SRC/QuixiDesk-${PKGVER}" ]; then
    echo "== using the tree already staged at $PREPARED"
    TREE="$PREPARED"
  else
    echo "== using the prepared tree at $PREPARED"
    rm -rf "$SRC"; mkdir -p "$SRC"
    cp -a "$PREPARED" "$SRC/"
    TREE="$SRC/QuixiDesk-${PKGVER}"
  fi
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
# Compile here, hand it in.
#
# Two things can be true of a prebuilt binary that exists and is executable and still wrong, and both
# shipped from this script once before anyone caught them:
#   * it was compiled without QUIXI_EDITION_LABEL, so the window title cannot be told apart from a
#     development build, and the one cheap proof of which artefact is running is gone;
#   * it was compiled without --remap-path-prefix, so it carries the builder's home directory in 678
#     strings — registry paths, workspace paths, the username — into every download.
# So the binary is inspected, not trusted: rebuild when the label is missing, and refuse outright when the
# home directory is still in it.
EDITION_LABEL_EXPECT="${QUIXI_EDITION_LABEL:-}"

# THE BINARY COMES OUT OF THE PACKAGE, NOT OUT OF WHATEVER THE TREE HAPPENS TO HOLD.
#
# Congruence between the two artefacts is not a matter of care, it is a matter of provenance: the
# Flatpak must ship the same bytes pacman installed in the published edition, or "same version" is a
# coincidence that a clean rebuild can break. So the newest package for this pkgver is opened and its
# /usr/lib/QuixiDesk is the one that gets packaged. The pkgrel it came from is printed and recorded, so
# anyone can check the two artefacts against each other afterwards.
PKG_FOR_BIN=""
for candidate in $(ls -t "$REPO"/quixidesk*-"${PKGVER}"-[0-9]*-x86_64.pkg.tar.zst 2>/dev/null); do
  case "$candidate" in *debug*) continue ;; esac
  PKG_FOR_BIN="$candidate"; break
done
if [ -n "$PKG_FOR_BIN" ]; then
  PKG_REL=$(basename "$PKG_FOR_BIN" | sed -E "s/.*-${PKGVER}-([0-9]+)-x86_64.*/\1/")
  echo "== taking the binary out of $(basename "$PKG_FOR_BIN") (pkgrel $PKG_REL)"
  EXTRACT=$(mktemp -d)
  tar --zstd -xf "$PKG_FOR_BIN" -C "$EXTRACT" 2>/dev/null || {
    echo "  ✗ cannot unpack $PKG_FOR_BIN" >&2; exit 1; }
  FOUND=$(find "$EXTRACT" -type f -name QuixiDesk -path "*/lib/*" | head -1)
  [ -n "$FOUND" ] || { echo "  ✗ no QuixiDesk binary inside that package" >&2; exit 1; }
  mkdir -p "$TREE/prebuilt"
  install -m755 "$FOUND" "$TREE/prebuilt/QuixiDesk"
  rm -rf "$EXTRACT"
  echo "  packaged binary: $(sha256sum "$TREE/prebuilt/QuixiDesk" | cut -c1-24)…  (pkgrel $PKG_REL)"
  printf '%s\n' "$PKG_REL" > "$WORK/pkgrel"
else
  echo "== no package for $PKGVER in $REPO — falling back to the tree's own binary"
fi

if [ ! -x "$TREE/prebuilt/QuixiDesk" ]; then
  echo "== building the binary"
  ( cd "$TREE" && QUIXI_EDITION_LABEL="$EDITION_LABEL_EXPECT" \
      cargo build --release -p quixi-app )
  mkdir -p "$TREE/prebuilt"
  cp "$TREE/target/release/QuixiDesk" "$TREE/prebuilt/QuixiDesk"
fi
if [ -n "$EDITION_LABEL_EXPECT" ]; then
  # Compare on the trimmed label. The literal is compiled in with a trailing space so the title bar reads
  # "(volkdude85 github) QuixiDesk"; whether that space survives into the string table is up to the
  # compiler, so requiring it here would fail a binary that is in fact correct.
  LABEL_NEEDLE="${EDITION_LABEL_EXPECT% }"
  # grep -c, not grep -q, and capture the count: `strings ... | grep -q` makes grep exit on the first match,
  # which SIGPIPEs strings, which `set -o pipefail` reports as a failed pipeline — so -q inside an `if !`
  # says "the label is missing" about a binary that has it. That cost three build attempts.
  LABEL_HITS=$(strings "$TREE/prebuilt/QuixiDesk" | grep -cF -- "$LABEL_NEEDLE" || true)
  if [ "${LABEL_HITS:-0}" -eq 0 ]; then
    echo "  ✗ prebuilt/QuixiDesk was compiled without QUIXI_EDITION_LABEL='$EDITION_LABEL_EXPECT'" >&2
    echo "    rebuild it with that variable set, or the shipped binary cannot be told from a dev build." >&2
    exit 1
  fi
  echo "  ✓ the binary carries the edition label: $EDITION_LABEL_EXPECT"
fi
LEAKS=$(strings "$TREE/prebuilt/QuixiDesk" | grep -c -- "$HOME" || true)
if [ "${LEAKS:-0}" -gt 0 ]; then
  echo "  ✗ prebuilt/QuixiDesk carries $LEAKS strings containing $HOME — that ships this machine's paths" >&2
  echo "    rebuild with RUSTFLAGS='... --remap-path-prefix=$HOME=/build' and a build dir outside $HOME." >&2
  exit 1
fi
echo "  ✓ no build-path leak in the binary"

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
# --gpg-sign here, not only at build-update-repo: this is the call that CREATES the commit, and the commit
# is the object the client verifies.
flatpak-builder --user --disable-cache --state-dir="$STATE" --force-clean --repo="$REPO_DIR" \
  --gpg-sign="$SIGN_KEY" --gpg-homedir="$SIGN_HOME" \
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

# --- fallback: patch series from the upstream tarball ---------------------------------------
# This path extracts the release and applies the series, and then it stops being able to help: it never
# produces the two things the repository's manifest needs — a directory source at ../flatpak-src, and the
# compiled binary inside it at prebuilt/QuixiDesk. Nothing here compiles Rust. flatpak-builder's answer to
# that gap is "Failed to init: Unable to find directory", which reads like a missing dependency and is not,
# and that misread costs an hour every time it happens. Refuse up front, in plain words.
if [ -z "${QUIXI_SERIES_PATH:-}" ]; then
  echo "== no prepared tree at $PREPARED — refusing to fall through to the patch-series path" >&2
  echo "   That path patches the tree but never compiles the binary and never builds the directory source" >&2
  echo "   the manifest points at, so it cannot package anything." >&2
  echo "   Prepare src/QuixiDesk-${PKGVER} with prebuilt/QuixiDesk beside flatpak/, or set QUIXI_SERIES_PATH=1" >&2
  echo "   if you are working on that path itself." >&2
  exit 1
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
  --gpg-sign="$SIGN_KEY" --gpg-homedir="$SIGN_HOME" \
  "$BUILD" "$TREE/flatpak/io.github.volkdude85.quixidesk.yml"

BUNDLE="$WORK/QuixiDesk.flatpak"
echo "== exporting $BUNDLE"
flatpak build-bundle "$REPO_DIR" "$BUNDLE" io.github.volkdude85.quixidesk
ls -la "$BUNDLE"

sign_repo
