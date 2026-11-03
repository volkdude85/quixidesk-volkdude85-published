#!/bin/sh
# QuixiCore — install, on whatever Linux this is.
#
#   sh install.sh              # the Flatpak
#   sh install.sh --container  # a distrobox container with the full dependency set (Deck / immutable)
#
# One rule: the Flatpak is the install path everywhere it exists, because it is the only one that
# brings its own runtime, drops into the menu, and updates itself afterwards. Everything below is
# about what is *around* that on this particular machine — and on a Steam Deck, the part that is
# around it is the part people get stuck on.
#
# The container route exists because a sandbox cannot run ydotool or a compositor capture daemon.
# It lives in your home directory so a SteamOS update does not erase it, and it costs a couple of
# gigabytes and an update step of its own. See STEAMDECK.md.
#
# Nothing here needs root, nothing here talks to anything but the repository it names, and you can
# read the whole file before you run it.

set -eu

APP_ID=org.quixidesk.QuixiDesk
REF_URL="https://volkdude85.github.io/quixidesk-volkdude85-published/org.quixidesk.QuixiDesk.flatpakref"
CONTAINER_SCRIPT="https://raw.githubusercontent.com/volkdude85/quixidesk-volkdude85-published/master/scripts/steamdeck-distrobox.sh"
RAW_BASE="https://raw.githubusercontent.com/volkdude85/quixidesk-volkdude85-published/master"
SHORTCUT_SCRIPT="$RAW_BASE/scripts/deck-steam-shortcut.py"

MODE=flatpak
for arg in "$@"; do
  case "$arg" in
    --container|container) MODE=container ;;
    --flatpak|flatpak)     MODE=flatpak ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) : ;;
  esac
done

say() { printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

os_id() {
  [ -r /etc/os-release ] || { echo unknown; return; }
  # shellcheck disable=SC1091
  . /etc/os-release
  printf '%s' "${ID:-unknown}"
}

is_steamdeck() {
  [ -r /etc/os-release ] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    steamos) return 0 ;;
  esac
  # Older images identify as arch with a steamos variant.
  [ "${VARIANT_ID:-}" = "steamdeck" ] && return 0
  [ -e /home/deck ] && return 0
  return 1
}

install_flatpak() {
  if flatpak list --app --columns=application 2>/dev/null | grep -qx "$APP_ID"; then
    say "== already installed"
    return 0
  fi
  say "== installing the Flatpak from the signed repository"
  if ! flatpak install --user -y --noninteractive --from "$REF_URL"; then
    say ""
    say "The install did not go through. If it said 'already installed', run:"
    say "    flatpak update $APP_ID"
    return 1
  fi
}

# Put the tile in the Steam library, with the artwork already in place, so Game Mode has something
# better than a grey rectangle. Steam must be closed for this — it rewrites shortcuts.vdf on exit.
add_steam_tile() {
  say ""
  say "== Steam library shortcut"
  if ! have python3; then
    say "python3 is not on PATH; skipping the shortcut. Add it by hand: Steam → Games →"
    say "Add a Non-Steam Game → browse to /usr/bin/flatpak, options: run $APP_ID"
    return 0
  fi

  work=$(mktemp -d)
  # Prefer the checkout this script is sitting in; fall back to the repository.
  if [ -f ./scripts/deck-steam-shortcut.py ]; then
    cp ./scripts/deck-steam-shortcut.py "$work/"
  else
    curl -fsSL "$SHORTCUT_SCRIPT" -o "$work/deck-steam-shortcut.py" || {
      say "could not fetch the shortcut script — skipping"; return 0; }
  fi

  art=""
  if [ -d ./steam ]; then
    art=./steam
  else
    mkdir -p "$work/art"
    for f in grid-460x215.png grid-600x900.png hero-1920x620.png logo-1280x720.png; do
      curl -fsSL "$RAW_BASE/steam/$f" -o "$work/art/$f" 2>/dev/null || true
    done
    [ -f "$work/art/grid-460x215.png" ] && art="$work/art"
  fi

  if pgrep -x steam >/dev/null 2>&1; then
    say "Steam is running — it rewrites its shortcut list on exit, so this waits."
    say "Close Steam, then run:"
    say "    python3 $SHORTCUT_SCRIPT --write --art ${art:-<repo>/steam}"
  else
    if [ -n "$art" ]; then
      python3 "$work/deck-steam-shortcut.py" --write --art "$art"
    else
      python3 "$work/deck-steam-shortcut.py" --write
    fi
  fi
  rm -rf "$work"
}

game_mode_steps() {
  cat <<'EOF'

Now the part that is not a command: getting it into Game Mode.

  1. In Desktop Mode, open Steam → Games → Add a Non-Steam Game.
  2. Switch the filter from Applications to All, or look for "volkdude85's QuixiCore".
     Flatpak applications live in ~/.local/share/flatpak/exports/share/applications, and
     Steam reads that directory — on most images the entry is simply in the list.
  3. If it is not in the list, choose "Browse" and pick /usr/bin/flatpak, then set the
     shortcut's Launch Options to:   run org.quixidesk.QuixiDesk
  4. In Game Mode, the shortcut launches the app; the on-screen keyboard (STEAM + X) is the
     keyboard, and the trackpads drive the pointer.

A note on the window: the app sizes itself to the display it opens on. On a 1280x800 Deck
that is 1240x720, so the composer and the Send button stay on screen. If you ever see a
window taller than the panel, the Flatpak is older than 3.6556.12-r2 — run: flatpak update
EOF
}

finish() {
  say ""
  say "Done. Launch it with:"
  say "    flatpak run $APP_ID"
  say ""
  say "Updates, forever after, are just:"
  say "    flatpak update $APP_ID"
}

# ---------------------------------------------------------------------------------------------

run_container_route() {
  say "== container route: distrobox, dependencies inside, nothing written to the OS image"
  if ! have distrobox; then
    say "distrobox is not installed. On SteamOS it is in the Discover store (it is a Flatpak)."
    say "Then run this again with --container."
    return 1
  fi
  # The script itself is in the repository — fetch it, do not reimplement it here, so there is one
  # copy of the container logic and it is the copy the documentation describes.
  tmp=$(mktemp)
  curl -fsSL "$CONTAINER_SCRIPT" -o "$tmp"
  say "== fetched scripts/steamdeck-distrobox.sh"
  sh "$tmp"
  rc=$?
  rm -f "$tmp"
  return $rc
}

if [ "$MODE" = container ]; then
  run_container_route || exit 1
  say ""
  say "The container survives SteamOS updates because it lives in ~/.local/share/containers."
  say "Enter it with:  distrobox enter quixi -- quixidesk"
  exit 0
fi

if is_steamdeck; then
  say "SteamOS / Steam Deck detected."
  if ! have flatpak; then
    say "Flatpak is not on PATH. On SteamOS it ships with the image — if this is a Deck,"
    say "you may be in a recovery or developer shell rather than a normal session."
    exit 1
  fi
  install_flatpak
  finish
  add_steam_tile
  game_mode_steps
  say ""
  say "If the agent needs to drive the mouse and keyboard, or read the clipboard, the sandbox is"
  say "the thing in the way — those need ydotool and wl-clipboard on the machine, which a Flatpak"
  say "cannot carry for you. That is the other route, and it is one command:"
  say "    sh install.sh --container"
  exit 0
fi

case "$(os_id)" in
  arch|artix|endeavouros|cachyos|manjaro|garuda)
    say "Arch-family system detected."
    if have flatpak; then
      install_flatpak
      finish
      say ""
      say "There is also a PKGBUILD that builds from source against your own webkit2gtk:"
      say "    https://github.com/volkdude85/quixidesk-volkdude85-published"
    else
      say "Install flatpak first:  sudo pacman -S flatpak"
    fi
    ;;
  debian|ubuntu|pop|linuxmint|elementary|zorin)
    say "Debian-family system detected."
    if have flatpak; then
      install_flatpak
      finish
    else
      say "Install flatpak first:  sudo apt install flatpak"
    fi
    ;;
  fedora|rhel|centos)
    say "Fedora-family system detected."
    if have flatpak; then
      install_flatpak
      finish
    else
      say "Install flatpak first:  sudo dnf install flatpak"
    fi
    ;;
  *)
    say "Unrecognised distribution — trying the Flatpak path anyway, since it is the one that"
    say "does not care what you are running."
    if have flatpak; then
      install_flatpak
      finish
    else
      say "Flatpak is not installed. See https://flatpak.org/setup/ for your distribution,"
      say "then run this again."
      exit 1
    fi
    ;;
esac
