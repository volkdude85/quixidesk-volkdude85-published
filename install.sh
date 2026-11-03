#!/bin/sh
# QuixiCore — install, on whatever Linux this is.
#
#   sh install.sh
#
# One rule: the Flatpak is the install path everywhere it exists, because it is the only one that
# brings its own runtime, drops into the menu, and updates itself afterwards. Everything below is
# about what is *around* that on this particular machine — and on a Steam Deck, the part that is
# around it is the part people get stuck on.
#
# Nothing here needs root, nothing here talks to anything but the repository it names, and you can
# read the whole file before you run it.

set -eu

APP_ID=org.quixidesk.QuixiDesk
REF_URL="https://volkdude85.github.io/quixidesk-volkdude85-published/org.quixidesk.QuixiDesk.flatpakref"

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

if is_steamdeck; then
  say "SteamOS / Steam Deck detected."
  if ! have flatpak; then
    say "Flatpak is not on PATH. On SteamOS it ships with the image — if this is a Deck,"
    say "you may be in a recovery or developer shell rather than a normal session."
    exit 1
  fi
  install_flatpak
  finish
  game_mode_steps
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
