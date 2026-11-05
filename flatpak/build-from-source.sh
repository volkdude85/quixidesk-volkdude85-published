#!/bin/bash
# Build the Flatpak from SOURCE, inside the sandbox — the shape Flathub requires.
#
#   ./flatpak/build-from-source.sh          build the .flatpak bundle
#   ./flatpak/build-from-source.sh --repo   also produce a signed OSTree repo, as the hub needs
#
# Why this exists next to build-flatpak.sh: that one hands flatpak-builder a binary somebody else
# compiled, which is what makes it fast and what makes it ineligible for Flathub. A store that
# distributes a binary it did not build cannot reproduce it, patch it, or answer for it. This script
# does the other thing — 564 crates from crates.io, compiled by cargo inside the sandbox, no network.
#
# The crate list is flatpak/cargo-sources.json, produced by flatpak-cargo-generator.py from Cargo.lock.
# It is 308 KB of URLs and sha256s, which is the only honest way to vendor 564 crates: a vendor/ tree in
# git would be hundreds of megabytes that nobody reviews.
#
# The Rust toolchain comes from org.freedesktop.Sdk.Extension.rust-stable, which is ~1.7 GB on first
# download and is the thing the old manifest's header called "1.7 GB of delta space this container does
# not have". That was true of the GitHub runner's disk; it is not true here.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$HOME/flatpak-source-build}"
PKGVER=$(sed -n 's/^pkgver=//p' "$REPO/PKGBUILD")
TREE_SRC="$REPO/src/QuixiDesk-${PKGVER}"
TEMPLATE="$REPO/flatpak/io.github.volkdude85.quixidesk.sourcebuild.yml"
MANIFEST="$WORK/io.github.volkdude85.quixidesk.json"
SOURCES="$REPO/flatpak/cargo-sources.json"
MAKE_REPO=0
[ "${1:-}" = "--repo" ] && MAKE_REPO=1

[ -d "$TREE_SRC" ] || { echo "no prepared tree at $TREE_SRC — run makepkg first" >&2; exit 1; }
[ -f "$SOURCES" ] || { echo "no $SOURCES — generate it from Cargo.lock first (see the header)" >&2; exit 1; }

mkdir -p "$WORK"
echo "== staging the tree at $WORK/src"
rm -rf "$WORK/src"; mkdir -p "$WORK/src"
# vendor/ is NOT excluded, and that is load-bearing: Cargo.toml line 67 is
#   rmcp = { path = "vendor/rmcp" }
# a patched fork of the crate as a workspace member, not a crates.io dependency. Excluding it builds right
# up to "unable to update /run/build/quixidesk/vendor/rmcp" — which is what the first attempt did.
rsync -a --exclude '/target/' --exclude '/prebuilt/' "$TREE_SRC/" "$WORK/src/"
cp -a "$REPO/flatpak" "$WORK/src/flatpak"   # the desktop entry, the metainfo, the launcher

echo "== merging the crate sources into the manifest"
python3 - "$TEMPLATE" "$SOURCES" "$MANIFEST" <<'PY'
import json, sys, yaml
template, sources_path, out = sys.argv[1:4]
manifest = yaml.safe_load(open(template))
crates = json.load(open(sources_path))
mod = manifest["modules"][0]
mod.setdefault("sources", [])
mod["sources"] = mod["sources"] + crates
json.dump(manifest, open(out, "w"), indent=2)
print(f"   {len(crates)} crate sources, manifest written to {out}")
PY

echo "== building with flatpak-builder (this compiles the application)"
rm -rf "$WORK/build" "$WORK/repo"
# --repo always: `flatpak build-bundle` takes a REPOSITORY, not a build directory. The first version
# only created one when asked to sign, so the bundle step at the bottom failed with "not a valid
# repository" on every unsigned build — and the fallback below it did nothing at all while the script
# reported success. A repo costs seconds and makes the last step possible.
ARGS=(--user --disable-cache --force-clean --state-dir="$WORK/state" --repo="$WORK/repo")
KEY="${QUIXI_FLATPAK_KEY:-BEA4F4E734ECF3EC}"
HOMEDIR="${QUIXI_FLATPAK_GNUPGHOME:-$HOME/.config/quixidesk-flatpak/gnupg}"
if [ "$MAKE_REPO" = 1 ]; then
  ARGS+=(--gpg-sign="$KEY" --gpg-homedir="$HOMEDIR")
fi
flatpak-builder "${ARGS[@]}" "$WORK/build" "$MANIFEST"

if [ "$MAKE_REPO" = 1 ]; then
  echo "== signing the repo"
  GNUPGHOME="${QUIXI_FLATPAK_GNUPGHOME:-$HOME/.config/quixidesk-flatpak/gnupg}" \
    flatpak build-update-repo --gpg-sign="${QUIXI_FLATPAK_KEY:-BEA4F4E734ECF3EC}" \
      --gpg-homedir="${QUIXI_FLATPAK_GNUPGHOME:-$HOME/.config/quixidesk-flatpak/gnupg}" \
      --generate-static-deltas "$WORK/repo"
  echo "   repo at $WORK/repo"
fi

echo "== exporting a bundle"
rm -f "$WORK/QuixiDesk-source.flatpak"
flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
  "$WORK/repo" "$WORK/QuixiDesk-source.flatpak" io.github.volkdude85.quixidesk
ls -lh "$WORK/QuixiDesk-source.flatpak"
