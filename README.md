# QuixiDesk for Arch Linux — volkdude85 edition (PBBBT)

[![build](https://github.com/volkdude85/quixidesk-volkdude85/actions/workflows/build.yml/badge.svg)](https://github.com/volkdude85/quixidesk-volkdude85/actions/workflows/build.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> **This is one of two editions.** Neither depends on the other — both patch the upstream
> `QuixiAI/QuixiDesk` release tarball directly, so you can clone either one on its own and it builds.
>
> * [`quixidesk-arch`](https://github.com/volkdude85/quixidesk-arch) — the restrained build, made in
>   the spirit of what Eric would want. Nothing personal baked in.
> * [`quixidesk-volkdude85`](https://github.com/volkdude85/quixidesk-volkdude85) — **PBBBT.** The extra
>   crazy vibe-coded edition. Wired to one specific machine, does cool shit, has opinions.
>
> |  |  |
> |---|---|
> | what differs, patch by patch | [`EDITIONS.md`](EDITIONS.md) |
> | every runtime, optional and external dependency, and why | [`DEPENDENCIES.md`](DEPENDENCIES.md) |
> | running it on a Steam Deck: SteamOS, read-only root, containers | [`STEAMDECK.md`](STEAMDECK.md) |
> | what is left wide open, and why | [`WAIVER.md`](WAIVER.md) — **read this before installing** |
> | how it got built, in order | [`CHANGELOG.md`](CHANGELOG.md) |
> | Artix / OpenRC (non-systemd) | [`ARTIX.md`](ARTIX.md) |

An Arch Linux package for [QuixiDesk](https://github.com/QuixiAI/QuixiDesk) that makes it actually work
on Linux.

QuixiDesk is Eric Hartford's MIT-licensed Rust/GTK desktop AI workspace. Upstream ships a macOS build;
the `ComputerUse` platform layer on Linux is a set of silent no-ops, so the app runs but cannot see the
screen, type, click, pick files, or enumerate displays. This package adds that layer and a few things
that were hard-coded or missing.

## What this adds

| patch | what it does |
|---|---|
| `0001-linux-support` | the platform layer: capture, clipboard, synthetic input, file pickers, display enumeration, window lookup, app launching |
| `0002-local-overrides` | lifts hard-coded product limits (rounds, subagents, attachments, timeouts) |
| `0003-condense-fallback` | keeps the context condense step from hard-failing at raised limits |
| `0004-skills` | a skills directory + searchable, paginated index exposed as a model tool |
| `0005-headless` | runs without a graphical session for CI |
| `0006-memory` | MemPalace-shaped memory (wings → rooms → drawers) — **local edition only** |
| `0007-voice` | local TTS + STT, defaults off |
| `0008-voice-local` | wires a specific local Kokoro/Whisper setup — **local edition only** |
| `0009-linux-fixes-keybindings` | keyboard-shortcut enumeration, normalised across desktops |
| `0010-rustify-keybindings` | replaces 25 subprocess spawns with one bulk call |
| `0011-test-portability` | fixes tests that asserted the author's environment instead of the contract |
| `0012-kde-scenario-pinning` | pins a KDE fall-through scenario to X11, where it is actually true |

Patches `0006` and `0008` are personal configuration and are excluded from the generic build.

## Build

```sh
makepkg -si
```

Requires `base-devel`. Everything else is resolved as a package dependency.

`options=('!lto')` is deliberate — makepkg's default `-flto=auto` breaks the `ring` link step with
undefined `ring_core_*` symbols.

## Verified

CI builds from a pristine upstream tarball and runs the full suite — patch application, build, tests,
package — on all of these:

| machine | CPU | desktop |
|---|---|---|
| AMD 7950X3D | Zen 4 | KDE Wayland |
| Intel i7-12700H | Alder Lake | GNOME Wayland, XFCE X11 |
| AMD 5800X | Zen 3 | XFCE, headless |

57 tests per run. Cross-desktop capability matrix: **46 checks, 46 passed**, across KDE, GNOME and
XFCE. That exercise ships in [`ci/`](ci/) here — `ci.sh`, `ci-probe.sh`, `watch-jobs.sh` and
`pick-auto.py`.

Running the suite on three machines is not ceremony: it found four real bugs that were invisible on
the machine the code was written on, three of them assertions about the developer's environment
(a hard-coded `"wayland"`, a screenshot-size heuristic, and a backend ordering that only holds on X11).

## What is Rust, and what is not

The platform layer is Rust, and so is every fix in `0009`–`0012`. A few things shell out on purpose,
because the system tool is the correct abstraction:

- **`ydotool`** — the only reliable way to synthesise input on Wayland. There is no in-process
  alternative without writing a compositor plugin per desktop.
- **`kdialog` / `zenity`** — native file pickers as a fallback when the XDG portal is unavailable.
- **`grim` / `spectacle` / `xfce4-screenshooter` / `import`** — capture backends, tried in order. KDE
  uses an in-process `ScreenShot2` D-Bus call first (29 ms versus ~921 ms via spectacle).

Everything else moved in-process: `.desktop` launching, active-output lookup, PNG region cropping,
Mutter display state, X11 capture/RandR/pointer via `x11rb`, clipboard, and HTTP (`curl` → `reqwest`).

## Known limits

- `cursor_position` returns `None` on Wayland — the pointer API does not expose a global position.
- `type_text` needs `-d 25` on Wayland (a per-character delay); X11 takes `-d 0`.
- File-picker dialogs require a real display. They cannot be tested on a headless box, and a headless
  negative result says nothing about the code.
- A box with no monitor runs Xorg at 0×0 unless the dummy driver config is passed explicitly with
  `-config`.

## Credits

QuixiDesk is by [QuixiAI](https://github.com/QuixiAI/QuixiDesk) (Eric Hartford), MIT. This repository
is a patch set against it, not a fork — the upstream tree is never modified. Memory is modelled on
MemPalace by Milla Jovovich (MIT).

## Licence

MIT. See `LICENSE`.
