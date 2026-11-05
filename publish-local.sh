#!/bin/bash
# One command: package the published edition, build the Flatpak from that exact package, install it.
#
#   ./publish-local.sh              build the package, then the Flatpak, then install it here
#   ./publish-local.sh --flatpak    skip makepkg; the Flatpak is rebuilt from the newest package on disk
#   ./publish-local.sh --no-install build both, leave the bundle, touch nothing that is installed
#
# Why this exists: the two artefacts are built by two different packagers — pacman and flatpak-builder —
# and nothing in either one forced them to carry the same code. They drifted exactly as you would
# expect: the published package moved to pkgrel 80 while the installed Flatpak sat on a commit from the
# previous morning, and the Flatpak had been built from a tree that still carried a redaction table
# with real names in it. Two artefacts, one series, one truth — and this script is where that stops
# being a promise and becomes a step that fails.
#
# The ordering is the whole design:
#   1. makepkg produces the package, which is the published edition's definition of itself.
#   2. build-flatpak.sh now takes the binary OUT OF THAT PACKAGE rather than out of the tree, so the
#      Flatpak cannot ship different bytes than pacman installed.
#   3. The bundle is installed, and then the deployed binary is hashed and compared with the package's.
#      If they differ, this script says so and exits non-zero rather than reporting success.
set -uo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
APP=io.github.volkdude85.quixidesk
WORK="${WORK:-$HOME/flatpak-build}"
BUNDLE="$WORK/QuixiDesk.flatpak"

DO_PKG=1
DO_INSTALL=1
for arg in "$@"; do
  case "$arg" in
    --flatpak) DO_PKG=0 ;;
    --no-install) DO_INSTALL=0 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\n=== %s\n' "$*"; }
die() { printf '\n  ✗ %s\n' "$*" >&2; exit 1; }

cd "$REPO" || die "cannot enter $REPO"
PKGVER=$(sed -n 's/^pkgver=//p' PKGBUILD)
[ -n "$PKGVER" ] || die "PKGBUILD has no pkgver"

# Serialise: two of these at once would fight over $WORK and over the flatpak-builder cache.
LOCK=/tmp/quixidesk-publish.lock
exec 9>"$LOCK" || die "cannot open lock $LOCK"
command -v flock >/dev/null && flock -n 9 || { echo "another publish is already running" >&2; exit 1; }

if [ "$DO_PKG" = 1 ]; then
  say "packaging $PKGVER"
  makepkg -f --nodeps --nocheck --skipinteg --noconfirm > "$WORK/makepkg.log" 2>&1 \
    || { tail -25 "$WORK/makepkg.log" >&2; die "makepkg failed — see $WORK/makepkg.log"; }
  grep -E "Finished making" "$WORK/makepkg.log" || true
fi

PKG=$(ls -t quixidesk*-"$PKGVER"-[0-9]*-x86_64.pkg.tar.zst 2>/dev/null | grep -v debug | head -1)
[ -n "$PKG" ] || die "no package for $PKGVER in $REPO — run without --flatpak to build one"
PKGREL=$(basename "$PKG" | sed -E "s/.*-${PKGVER}-([0-9]+)-x86_64.*/\1/")

say "building the Flatpak from $(basename "$PKG")"
./flatpak/build-flatpak.sh || die "the Flatpak build refused"
[ -f "$BUNDLE" ] || die "no bundle at $BUNDLE"

if [ "$DO_INSTALL" = 1 ]; then
  say "installing $APP from the bundle"
  flatpak install --user -y --reinstall "$BUNDLE" >/dev/null 2>&1 || die "flatpak install failed"
fi

# The gate. A successful build and a successful install still do not prove the two artefacts agree —
# that is exactly the pair of facts that were true while the installed Flatpak was a day stale. So the
# binary that is now deployed is hashed and compared with the one inside the package.
DEPLOY="$HOME/.local/share/flatpak/app/$APP/x86_64/master/active/files/bin/QuixiDesk"
TMP=$(mktemp -d)
tar --zstd -xf "$PKG" -C "$TMP" 2>/dev/null || die "cannot unpack $PKG"
PKG_BIN=$(find "$TMP" -type f -name QuixiDesk -path "*/lib/*" | head -1)
[ -n "$PKG_BIN" ] || die "no binary inside $PKG"
PKG_SHA=$(sha256sum "$PKG_BIN" | cut -d' ' -f1)
rm -rf "$TMP"

say "congruence check — pkgrel $PKGREL"
printf '  package binary   %s\n' "$PKG_SHA"
if [ -x "$DEPLOY" ]; then
  FLAT_SHA=$(sha256sum "$DEPLOY" | cut -d' ' -f1)
  printf '  flatpak binary   %s\n' "$FLAT_SHA"
  if [ "$PKG_SHA" = "$FLAT_SHA" ]; then
    printf '\n  ✓ the Flatpak ships the same binary as the published package (pkgrel %s)\n' "$PKGREL"
  else
    printf '\n  ✗ the deployed Flatpak binary is NOT the package binary\n' >&2
    exit 1
  fi
else
  printf '  (nothing deployed yet — built only)\n'
fi

# The other half of the check, and the half that survives a different machine. The binary above can only
# be compared with another build ON THIS BOX; the src id is the one CI can be compared against, because
# it hashes what the app renders from rather than what the compiler emitted.
printf '  src id           %s\n' "$(./flatpak/source-id.sh --package "$PKG" | awk '{print $2}')"

COMMIT=$(flatpak info "$APP" 2>/dev/null | awk '/Commit:/{print $2}')
[ -n "$COMMIT" ] && printf '  flatpak commit   %s\n' "$COMMIT"
printf '\n  bundle: %s\n' "$BUNDLE"
printf '  next:   push %s to the site repo if this one is going out\n' "$(basename "$PKG")"
