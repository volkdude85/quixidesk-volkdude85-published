#!/usr/bin/env bash
# Install QuixiDesk into a distrobox container on SteamOS.
#
# Why a container and not the image: SteamOS has a read-only root and an A/B update scheme, so
# anything installed to /usr is erased by the next OS update. A distrobox container lives in your
# home, survives those updates, and shares your home directory — which means ~/.quixi (chats,
# persona, memory, settings) is your real one and outlives the container itself.
#
#   ./steamdeck-distrobox.sh                     # build the container and install dependencies
#   ./steamdeck-distrobox.sh quixidesk-*.pkg.tar.zst   # the above, then install that package
#
# Re-running is safe: an existing container is reused, not recreated.
set -euo pipefail

CONTAINER="${QUIXI_CONTAINER:-quixi}"
IMAGE="${QUIXI_IMAGE:-archlinux:latest}"
PKG="${1:-}"

say() { printf '\n== %s\n' "$*"; }

command -v distrobox >/dev/null 2>&1 || {
  echo "distrobox is not installed." >&2
  echo "On SteamOS, install it from the Discover store (it is in Flathub) or via your package manager." >&2
  exit 1
}

# A read-only root does not stop distrobox: it writes to ~/.local/share/containers.
say "container: $CONTAINER ($IMAGE)"
if distrobox list --no-color 2>/dev/null | awk '{print $2}' | grep -qx "$CONTAINER"; then
  echo "already exists — reusing"
else
  distrobox create --name "$CONTAINER" --image "$IMAGE" --yes
fi

say "dependencies"
# The hard runtime set from DEPENDENCIES.md. Installed inside the container, not on the Deck.
distrobox enter "$CONTAINER" -- sudo pacman -Syu --noconfirm --needed \
  gtk3 webkit2gtk-4.1 glib2 pango cairo gdk-pixbuf2 libsoup3 openssl \
  hicolor-icon-theme dbus libpulse bash \
  ydotool wl-clipboard kdialog zendialog zenity 2>/dev/null || \
distrobox enter "$CONTAINER" -- sudo pacman -Syu --noconfirm --needed \
  gtk3 webkit2gtk-4.1 glib2 pango cairo gdk-pixbuf2 libsoup3 openssl \
  hicolor-icon-theme dbus libpulse bash ydotool wl-clipboard

# The two editions install to different paths. Resolve it inside the container instead of assuming
# one, so this script is the same script in both repositories.
APPDIR="${QUIXI_APPDIR:-}"
if [[ -z "$APPDIR" ]]; then
  APPDIR=$(distrobox enter "$CONTAINER" -- bash -lc '
    for d in /usr/lib/quixidesk /usr/lib/quixidesk-custom; do
      [ -x "$d/QuixiDesk" ] && { echo "$d"; exit 0; }
    done' 2>/dev/null | tail -1)
fi
if [[ -z "$APPDIR" ]]; then
  echo "QuixiDesk is not installed in the container yet — pass a .pkg.tar.zst to install it." >&2
  APPDIR="/usr/lib/quixidesk-custom"
else
  echo "app: $APPDIR"
fi

if [[ -n "$PKG" ]]; then
  [[ -f "$PKG" ]] || { echo "no such package: $PKG" >&2; exit 1; }
  say "installing $(basename "$PKG")"
  # The file is on the host; distrobox shares $HOME, so an absolute host path works inside.
  distrobox enter "$CONTAINER" -- sudo pacman -U --noconfirm "$(readlink -f "$PKG")"
else
  say "no package given — dependencies only"
  echo "Pass a .pkg.tar.zst to install it, or build one inside the container."
fi

say "launcher"
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/quixidesk-distrobox.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=QuixiDesk (distrobox)
Comment=QuixiDesk running inside the $CONTAINER container
Exec=distrobox enter $CONTAINER -- $APPDIR/QuixiDesk
Terminal=false
Categories=Development;Utility;
DESKTOP
echo "wrote $DESKTOP_DIR/quixidesk-distrobox.desktop"

say "done"
cat <<'NEXT'
Start it from the application menu, or:
    distrobox enter quixi -- '<the app dir printed above>'/QuixiDesk

Your data is in ~/.quixi on the Deck itself, shared with the container, so rebuilding
the container does not lose chats, persona or settings.
NEXT
