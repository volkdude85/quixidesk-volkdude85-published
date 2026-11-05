#!/bin/bash
# One short fingerprint for "what source is this artefact made of".
#
#   ./flatpak/source-id.sh                            the prepared tree in this repo
#   ./flatpak/source-id.sh <tree>                     any prepared tree
#   ./flatpak/source-id.sh --package <pkg.tar.zst>    the resources inside a built package
#
# Prints two ids:
#
#   src <16 hex>   every file under resources/ — the UI, the persona, the workflows, the icons.
#                  This is what a person actually sees, and it is the only thing that can be compared
#                  across machines, because it is data and not a build.
#   series <16hex> the patch names in prepare() order, each with its own content hash. Only the tree
#                  side can compute this; a package carries no patches, only their result.
#
# WHY THIS EXISTS, AND WHY IT IS NOT A BINARY HASH.
#
# Three producers make "the published edition" and none of them can produce the same executable:
#
#   makepkg on this box             glibc, this compiler, this machine
#   ci/ci.sh in archlinux:latest    a container, same family, a different build
#   flatpak.yml on ubuntu-latest    a different libc, compiled on the runner
#
# A sha256 of the binary answers "did these come from the same BUILD", which is never yes across
# machines — so it looks like a check and cannot fail. What must match is the SOURCE. Two artefacts with
# the same `src` id are the same code whatever the compiler did; different ids mean something drifted,
# which is exactly the failure that shipped a redaction table with real names in it, unnoticed, while
# every build was green.
#
# The binary hash has its own job, on its own machine: publish-local.sh compares the installed Flatpak
# against the package it was cut from, where the two really must be identical.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
resources_id() { ( cd "$1" && find resources -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16 ); }

if [ "${1:-}" = "--package" ]; then
  pkg="${2:?usage: source-id.sh --package <file>}"
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  tar --zstd -xf "$pkg" -C "$tmp" 2>/dev/null || { echo "cannot unpack $pkg" >&2; exit 1; }
  root=$(dirname "$(find "$tmp" -type d -name resources | head -1)")
  [ -d "$root/resources" ] || { echo "no resources/ in $pkg" >&2; exit 1; }
  printf 'src %s\n' "$(resources_id "$root")"
  exit 0
fi

tree="${1:-$here/src/QuixiDesk-$(sed -n 's/^pkgver=//p' "$here/PKGBUILD")}"
[ -d "$tree" ] || { echo "no prepared tree at $tree" >&2; exit 1; }

series=$(sed -n '/^prepare()/,/^build()/p' "$here/PKGBUILD" \
         | grep -oE '[0-9]{4}-[a-z0-9-]+\.patch' | awk '!seen[$0]++' \
         | while read -r p; do
             printf '%s %s\n' "$p" "$(find "$here/patches" -name "$p" -exec sha256sum {} \; | cut -c1-16)"
           done)

printf 'src %s\n'    "$(resources_id "$tree")"
printf 'series %s\n' "$(printf '%s\n' "$series" | sha256sum | cut -c1-16)"
