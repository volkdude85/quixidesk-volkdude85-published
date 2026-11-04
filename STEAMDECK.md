# Steam Deck compatibility — read this before installing

> ## This is a desktop application running on a handheld.
>
> It works on a Steam Deck. It is not a Deck experience. There is no gamepad UI, no Deck-verified
> control scheme, and the parts that need a keyboard are as awkward as any desktop program on that
> hardware. **If a Deck is the only machine you have, plan on one hour of setup and a second hour of
> learning the workarounds.**
>
> The short version: **Route A (container) or Route B (the Flatpak this edition ships) are the installs
> that survive. Desktop mode is where you use it. Game mode is a launcher, not a home.** Everything
> below is why, feature by feature, so you can decide before you install instead of after.

**Open question:** whether the window fills a Deck's panel in Game Mode is not established — see
[issue #1](https://github.com/volkdude85/quixidesk-volkdude85-published/issues/1) for what was measured
and what would settle it.

Every compatibility wall hit while packaging this, with the cause and the fix for each — including the
ones that are not fixed yet — is in [`DECK-PROBLEM-LOG.md`](DECK-PROBLEM-LOG.md).

Unlike the `quixidesk-arch` edition — which ships only the PKGBUILD and points Deck users here — this
edition carries a Flatpak manifest and a workflow that builds it.

---

## Compatibility at a glance

Measured on SteamOS 3, desktop mode, app running from a distrobox container. "Works" means it was
exercised, not that it was designed for this.

| Feature | On Deck | Notes |
|---|---|---|
| Launching the app | **Works** | From the application menu via the generated `.desktop` entry, or a terminal inside the container. |
| Chat, personas, memory palace, settings | **Works** | Plain GTK. The 1280×800 panel is small but everything is reachable; the window resizes on both axes. |
| Providers — cloud | **Works** | No GPU involved. |
| Providers — local models | **Works, slowly** | The APU is not a 4090. A 27B model is not a Deck workload; a small model on the GPU is fine. |
| Screen capture | **Works in desktop mode** | Needs `spectacle` or `grim` in the container. **Fails in game mode** — there is no compositor surface to capture the way a desktop offers one. |
| Input synthesis (the app driving mouse and keyboard) | **Works only with `ydotoold`** | `ydotool` plus a running daemon inside the container. This is the piece most often missing, and its absence reads as "it ignored me". |
| Clipboard read/write | **Works** | Needs `wl-clipboard` or `xclip` in the container. |
| Dictation (speech to text) | **Works only with a service** | Needs an STT endpoint listening on the machine. Without one, dictation says so rather than failing silently. |
| Read aloud (text to speech) | **Works only with a service** | Same shape: a Kokoro-style HTTP endpoint, or a command. |
| File pickers | **Works** | `kdialog` or `zenity` in the container; the portal path is not relied on. |
| Game mode | **Launches, and that is all** | No on-screen keyboard integration for the composer, no per-app scaling, no controller navigation. Add it as a non-Steam shortcut if you want a tile. |
| Sleep / resume | **Untested** | The app was not built around suspend. Assume a resume needs a fresh window. |
| Surviving a SteamOS update | **Yes** with Route A or B | Killed by Route C every time, by design of the OS. |

## Which install

### Route A — a container (recommended)

Install into a mutable container instead of the OS image: it lives in your home, so SteamOS updates do
not touch it, and your `~/.quixi` stays your real data directory.

```sh
./scripts/steamdeck-distrobox.sh                                  # container + dependencies
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

### Route B — the Flatpak

This edition ships one: `flatpak/io.github.volkdude85.quixidesk.yml`, built by `.github/workflows/flatpak.yml`.
Flatpak is the sanctioned way to put software on a Deck, and it is the only route that survives an OS
update with nothing to maintain.

The sandbox is the trade. A Flatpak reaches the home directory and the display sockets, but the two
things this app does that a normal app does not — injecting input through `ydotoold`, and capturing the
screen through the compositor — depend on what the sandbox permits and on what the host ships. Expect
to grant permissions, and expect the input path to be the one that needs them.

### Route C — make the root writable (not recommended)

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

## What SteamOS actually is

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

## Plain Arch on the hardware

If the Deck is running actual Arch (or Artix), none of the above applies: the root is writable, the
keyring is normal, `pacman -U` works, and updates do not erase your packages. This is the least
surprising environment of the three, and it is what the package is built and tested against.

Note that "immutable" is a SteamOS decision, not an Arch one. Artix gets you off systemd; it is not an
escape from immutability, because plain Arch was never immutable to begin with.

## Small-screen reality

- **Display** is 1280×800. The window opens larger than that by default; use the resize handle, or let
  it tile. It resizes on both axes and remembers the width.
- **Text entry** in game mode is a Steam keyboard problem, not ours. Run in desktop mode (or use the
  on-screen keyboard) for anything that needs typing into a composer.
- **Voice** needs an STT/TTS service listening on the machine; without one, dictation says so rather
  than failing silently.

## If something is broken

Say which route you used, whether you were in desktop or game mode, and what the app said it could not
do. The capability panel reports what each backend answered, which turns "it doesn't work" into a
missing dependency most of the time.
