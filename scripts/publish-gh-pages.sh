#!/bin/bash
# Publish the signed Flatpak repository to the gh-pages branch.
#
# What lives on gh-pages, at the site root:
#   - the OSTree repository itself (from flatpak/build-flatpak.sh, ~/flatpak-build/repo)
#   - <id>.flatpakref and <id>.flatpakrepo, which carry the remote URL and the signing key
#   - the icon and the screenshots the metainfo points at
#   - index.html, the human-facing install page
#
# The trap this script exists to avoid: a `rsync --delete` of the repo onto the branch eats
# index.html, the .flatpakref and the icon, because they are not part of the OSTree repo.
# An earlier publish did exactly that and had to be recovered from git. So the sync deletes
# nothing and the extra files are written after it, explicitly.
#
# usage: scripts/publish-gh-pages.sh [--build] [--no-push]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ID="io.github.volkdude85.quixidesk"
SITE="https://volkdude85.github.io/quixidesk-volkdude85-published"
WORK="${WORK:-$HOME/flatpak-build}"
KEY="${QUIXI_FLATPAK_KEY:-BEA4F4E734ECF3EC}"
GNUPGHOME_DIR="${QUIXI_FLATPAK_GNUPGHOME:-$HOME/.config/quixidesk-flatpak/gnupg}"
BUILD=0; PUSH=1
for a in "$@"; do
  case "$a" in
    --build) BUILD=1 ;;
    --no-push) PUSH=0 ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done

[ "$BUILD" = 1 ] && bash "$REPO_DIR/flatpak/build-flatpak.sh"

[ -f "$WORK/repo/config" ] || { echo "no signed repo at $WORK/repo — run build-flatpak.sh" >&2; exit 1; }
REF=$(cat "$WORK/repo/refs/heads/app/$ID/x86_64/master" 2>/dev/null) \
  || { echo "the repo has no ref for $ID — was it built from this manifest?" >&2; exit 1; }
echo "== publishing $ID at $REF"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# ssh, not https: this box authenticates to GitHub with a key, and the credential helper is unset,
# so an https clone can read but the push then blocks on a username prompt that never comes.
git clone -q --depth 1 --branch gh-pages git@github.com:volkdude85/quixidesk-volkdude85-published.git "$TMP/ghp" \
  || { echo "could not clone gh-pages" >&2; exit 1; }

# 1. the OSTree repo, no deletes
rsync -a --exclude '.git' "$WORK/repo/" "$TMP/ghp/"

# 2. the install channel files, generated here so they can never lag the ref
# The signing key has to be in the REF as well as the REPO file. A flatpakref install on a
# machine that has never seen this channel adds the remote itself, and without GPGKey here it
# adds it with gpg-verify=true and no key at all — every pull then dies with "no signatures
# found" on a commit that is, in fact, signed. That is exactly how the first published channel
# failed to install anywhere but this box.
GPGKEY=$(GNUPGHOME="$GNUPGHOME_DIR" gpg --export --armor "$KEY" | base64 -w0)
cat > "$TMP/ghp/$ID.flatpakref" <<EOF
[Flatpak Ref]
Title=QuixiDesk (volkdude85 edition)
Name=$ID
Branch=master
Url=$SITE/
SuggestRemoteName=quixidesk
RuntimeRepo=https://dl.flathub.org/repo/flathub.flatpakrepo
IsRuntime=false
GPGKey=$GPGKEY
EOF

cat > "$TMP/ghp/$ID.flatpakrepo" <<EOF
[Flatpak Repo]
Title=QuixiDesk (volkdude85 edition)
Url=$SITE/
Homepage=https://github.com/volkdude85/quixidesk-volkdude85-published
Comment=Native Rust desktop workspace for AI, volkdude85 edition
Description=A desktop workspace that runs AI models locally or over the internet, keeps its memory in a folder of markdown you own, and works on your files.
Icon=$SITE/$ID.png
GPGKey=$GPGKEY
EOF

# 3. icon and screenshots (the metainfo points at the site, so they have to be here too).
# The mark lives in the APPLICATION tree, not in this repository — the repo carries the patch
# series and the packaging files. Take it from the staged source tree the build just used, and
# fall back to the packaged copy if that tree has been cleaned.
ICON=""
for c in "$WORK/src/QuixiDesk-"*/resources/quixi-mark.svg \
         "$REPO_DIR/src/QuixiDesk-"*/resources/quixi-mark.svg \
         "$REPO_DIR/pkg/quixidesk-custom/usr/lib/quixidesk-custom/resources/quixi-mark.svg"; do
  [ -f "$c" ] && { ICON="$c"; break; }
done
[ -n "$ICON" ] || { echo "could not find quixi-mark.svg" >&2; exit 1; }
rsvg-convert -w 256 -h 256 "$ICON" -o "$TMP/ghp/$ID.png"
rsync -a "$REPO_DIR/screenshots/" "$TMP/ghp/screenshots/"
# The recording and its transcript, straight through — the page embeds them.
rsync -a "$REPO_DIR/voice/" "$TMP/ghp/voice/"

# 4. the page itself comes from site/index.html in this repository, not from the branch.
# It used to exist only on gh-pages, which meant the only copy of the install page was one
# force-push away from being lost. scripts/build-site.py regenerates it (current id, current
# runtime, the transcript reflowed from voice/quixidesk-voice.txt).
cp "$REPO_DIR/site/index.html" "$TMP/ghp/index.html"

# 4. the install line on the page follows the id, always
python3 - "$TMP/ghp/index.html" "$ID" "$SITE" <<'PY'
import re, sys
path, appid, site = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
s = re.sub(r'https://[^"\s<]+/[A-Za-z0-9._-]+\.flatpakref', f'{site}/{appid}.flatpakref', s)
open(path, 'w').write(s)
print("index.html install line ->", f'{site}/{appid}.flatpakref')
PY

# 5. stale id files would keep serving a dead remote
rm -f "$TMP/ghp/org.quixidesk.QuixiDesk.flatpakref" "$TMP/ghp/org.quixidesk.QuixiDesk.flatpakrepo"

cd "$TMP/ghp"
git add -A
if git diff --cached --quiet; then
  echo "== nothing changed"; exit 0
fi
git -c user.name="volkdude85" -c user.email="seanwvolk@gmail.com" \
  commit -q -m "Publish ${REF:0:8}: $ID"
echo "== committed $(git log --oneline -1)"
if [ "$PUSH" = 1 ]; then
  git push -q origin gh-pages
  echo "== pushed gh-pages"
else
  echo "== --no-push: staged at $TMP/ghp"
fi
