# Running this on a Steam Deck

The Deck is not a normal Arch install, and the difference bites before you get to the app. This is the
practical version: what the machine actually is, what breaks, and the three ways people get around it.

## What you are dealing with

SteamOS 3 is Arch-based with a **read-only root filesystem** and an **A/B image scheme**. The OS lives
on two partitions and an update is written to the inactive one, then swapped in on reboot.

Consequences, in order of how quickly they surprise people:

- `pacman -U ours.pkg.tar.zst` fails, because it writes to `/usr` and `/` is read-only.
- Even after making the root writable, `pacman` refuses with a keyring error: the pacman keyring on
  SteamOS is not populated the way a normal Arch install's is.
- Anything you install that way is **gone after the next OS update**. The update replaces the image; it
  does not merge with what you changed.

That third point is the one that matters. Disabling the read-only root is not a one-time setup, it is a
ritual you repeat after every SteamOS update.

## Route C — make the root writable (not recommended)

The direct route. Repeat after every OS update.

```sh
sudo steamos-readonly disable
sudo pacman-key --init
sudo pacman-key --populate archlinux holo
sudo pacman -U quixidesk-custom-3.6556.12-*.pkg.tar.zst
sudo steamos-readonly enable        # optional; leaving it writable is how things get broken
```

What you get: the app installed system-wide, startable from the desktop or a game-mode shortcut.

What you accept: after the next system update, it is gone and you do this again. `/usr` is shared with
the OS, so a package that writes there can also conflict with something Valve ships.

## Route A — a container (recommended)

The one to use. Install into a mutable container instead of the OS image: it lives in your home, so
SteamOS updates do not touch it, and your `~/.quixi` stays your real data directory.

There is a script that does the whole thing:

```sh
./scripts/steamdeck-distrobox.sh                          # container + dependencies
./scripts/steamdeck-distrobox.sh quixidesk-custom-*.pkg.tar.zst   # and install the package
```

By hand it is the same three steps:

```sh
distrobox create --name quixi --image archlinux:latest
distrobox enter quixi
sudo pacman -Syu --noconfirm gtk3 webkit2gtk-4.1 glib2 pango cairo gdk-pixbuf2 libsoup3 \
     openssl hicolor-icon-theme dbus libpulse bash
```

then install the package inside the container as normal.

GUI apps launched from inside a distrobox appear on the Deck's desktop like native windows. The app's
data directory is your real home directory, so chats, persona and settings persist across container
rebuilds — and the container survives SteamOS updates because it is not part of the image.

The script also writes a `.desktop` entry, so it shows up in the application menu without a terminal.

## Route B — plain Arch on the hardware

If the Deck is running actual Arch (or Artix), none of the above applies: the root is writable, the
keyring is normal, `pacman -U` works, and updates do not erase your packages. This is the least
surprising environment of the three, and it is what the package is built and tested against.

Note that "immutable" is a SteamOS decision, not an Arch one. Artix gets you off systemd; it is not an
escape from immutability, because plain Arch was never immutable to begin with.

## What to expect on the hardware itself

- **Display** is 1280×800. The window opens at 1280×840 by default on a desktop; use the resize handle
  or let it tile.
- **Text entry** in game mode is a Steam keyboard problem, not ours. Run in desktop mode (or use the
  on-screen keyboard) for anything that needs typing into a composer.
- **Input synthesis** (the app driving the mouse and keyboard) needs `ydotool` and a running
  `ydotoold`. On SteamOS that has to come from Route A or B like everything else, and it is the piece
  most likely to be missing.
- **Voice** needs an STT/TTS service listening on the machine; without one, dictation reports that it
  is unavailable rather than failing silently.

## What we do not do

We do not ship a Flatpak. Flatpak is the sanctioned way to put software on a Deck and we have not built
one, so the two supported routes are A and B. If a SteamOS update removes the app, that is expected
behaviour for Route A, not a bug.
