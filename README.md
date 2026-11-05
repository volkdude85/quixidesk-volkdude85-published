# QuixiDesk for Arch Linux — volkdude85 edition (PBBBT)

[![build](https://github.com/volkdude85/quixidesk-volkdude85-published/actions/workflows/build.yml/badge.svg)](https://github.com/volkdude85/quixidesk-volkdude85-published/actions/workflows/build.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> **This is one of two editions.** Neither depends on the other — both patch the upstream
> `QuixiAI/QuixiDesk` release tarball directly, so you can clone either one on its own and it builds.
>
> * [`quixidesk-arch`](https://github.com/volkdude85/quixidesk-arch) — the restrained build, made in
>   the spirit of what Eric would want. Nothing personal baked in.
> * [`quixidesk-volkdude85-published`](https://github.com/volkdude85/quixidesk-volkdude85-published) — **PBBBT.** The extra
>   crazy vibe-coded edition. Wired to one specific machine, does cool shit, has opinions.
>
> **On a Steam Deck?** Read [`STEAMDECK.md`](STEAMDECK.md) before you install. It is a desktop
> application on a handheld: desktop mode works, game mode launches it and nothing more, and the input
> path needs `ydotoold` to exist.
>
> |  |  |
> |---|---|
> | what differs, patch by patch | [`EDITIONS.md`](EDITIONS.md) |
> | every runtime, optional and external dependency, and why | [`DEPENDENCIES.md`](DEPENDENCIES.md) |
> | **running it on a Steam Deck — compatibility, caveats, and what does not work** | **[`STEAMDECK.md`](STEAMDECK.md)** |
| **every wall hit making it ship, and the fix for each** | [`DECK-PROBLEM-LOG.md`](DECK-PROBLEM-LOG.md) |
| **why it is not on Flathub, in Flathub's own words** | [`FLATHUB.md`](FLATHUB.md) |
| **setting it up in pictures, for anyone who would rather look than read** | [`docs/SETUP-VISUAL.md`](docs/SETUP-VISUAL.md) |
> | what is left wide open, and why | [`WAIVER.md`](WAIVER.md) — **read this before installing** |
| **how it got built, in order** | [`CHANGELOG.md`](CHANGELOG.md) |
| **what the first run says, and why it is worded that way** | [`ONBOARDING.md`](ONBOARDING.md) |
> | Artix / OpenRC (non-systemd) | [`ARTIX.md`](ARTIX.md) |

An Arch Linux package for [QuixiDesk](https://github.com/QuixiAI/QuixiDesk) that makes it actually work
on Linux.

QuixiDesk is Eric Hartford's MIT-licensed Rust/GTK desktop AI workspace. Upstream ships a macOS build;
the `ComputerUse` platform layer on Linux is a set of silent no-ops, so the app runs but cannot see the
screen, type, click, pick files, or enumerate displays. This package adds that layer and a few things
that were hard-coded or missing.

### Who writes this

Me, with an AI doing the actual typing, and I'd rather say that up front than have it come out sideways
later. I'm dyslexic. I'm a decent technician and I was never an engineer, so I decide what the software
has to do, read what comes back, and run it on real hardware until it stops lying to me. The agent types
the patch; the judgement and the testing are mine. Every patch in this series came out of that loop —
ninety-odd of them — and I'll stand behind all of them. This is my edition. My name's on it, and when a
runtime goes end of life, I'm the one who moves it. If that's a problem for you, I'd rather hear it now
than after you've decided.

### What it is underneath the packaging

This edition ships a persona called **Nora**, and the first-run screen carries an **About Nora** panel
that answers the obvious question — *why would I want an assistant that was built for a disabled
person?* — by naming what it is rather than implying it: not a chatbot answering to a company, but an
assistance device, built first for one person with a disability and only afterwards made installable.

The legal category is stated, because it is the reason the door opens: ADA **Title II** for public
entities (a courthouse, a clerk's window, a school office), **Title III** for places of public
accommodation (a doctor's office, a pharmacy, a lawyer's waiting room), **Section 504** of the
Rehabilitation Act for a federal court under Article III, and **28 CFR 35.160** on auxiliary aids and
services — the entity furnishes the aid and gives primary consideration to the person who will use it.
That is what makes somebody's own software an accommodation rather than a workaround.

Nothing asks for a diagnosis and nothing checks. The copy, and the reasoning behind each sentence
including why it says "assistance device" and not "medical device":
[`ONBOARDING.md`](ONBOARDING.md#2-the-about-block-and-why-it-is-worded-the-way-it-is).

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

**Hermes, and the tool library inside this app, are [Nous Research](https://nousresearch.com)'s work.**
The agent that reads skills, the hundreds of tools and procedures that the "Hermes" panel lists, the
conventions they follow — none of it is ours. We tap it live from the Hermes profiles on the machine,
we credit it in the app where a reader sees it, and we say so here as plainly as we can: **full credit
to Nous Research, and thank you.** Hermes is a genuinely good product and it is the reason the tools
panel in this build has anything worth listing.

* **Hermes / Hermes Agent** — Nous Research (MIT). The agent framework, the skill format, and the
  majority of the tool instructions this app surfaces.
* **QuixiDesk** — [QuixiAI](https://github.com/QuixiAI/QuixiDesk), Eric Hartford (MIT). This
  repository is a patch set against it, not a fork; the upstream tree is never modified.
* **Memory** — modelled on MemPalace by Milla Jovovich (MIT).
* Individual skills that came in from elsewhere carry their own author line in the skill itself and
  are listed one row each in `ATTRIBUTION.md`/`MANIFEST.tsv` where that file exists. If a skill says
  someone else wrote it, they did, and the mistakes in it are not theirs.

## Licence

MIT. See `LICENSE`.

## Install, on a Deck or anywhere else

```sh
sh install.sh
```

One script, no root, and it reads `/etc/os-release` before it does anything. On **SteamOS** it says
so, installs the Flatpak from the signed repository, and then prints the part that is not a command:
how to get the shortcut into Game Mode, where Steam looks for Flatpak applications, and what to do
when the entry is not in that list. On Arch it also points at the PKGBUILD; on Debian and Fedora it
names the one package to install if Flatpak is missing; on anything else it takes the Flatpak path
anyway, because that is the one that does not care what you are running.

The same install, by hand:

```sh
flatpak install --user --from https://volkdude85.github.io/quixidesk-volkdude85-published/io.github.volkdude85.quixidesk.flatpakref
```

That URL is a signed OSTree repository — the key travels in the `.flatpakref`, so `flatpak update`
keeps working afterwards and every commit it installs is verified.

#### Two Flatpaks, and which one is which

This repository builds and signs **its own** Flatpak, id `io.github.volkdude85.quixidesk`, from the
patch series in this tree. That is the one the install line above installs, and it always carries this
edition.

The Flathub submission is a different package with a different id — `io.github.volkdude85.QuixiDesk` —
and it does not depend on this repository at all. Its manifest and PR branch live in
[`volkdude85/flathub`](https://github.com/volkdude85/flathub), and it builds from a tagged tarball
released at [`volkdude85/QuixiDesk`](https://github.com/volkdude85/QuixiDesk): upstream `v3.6556.12`
with the Linux platform series already applied. That fork exists for one reason — a Flathub app id of
the form `io.github.<user>.<App>` has to map to a GitHub repository of that name, and the tarball has
to be a release asset somewhere public.

If Flathub accepts it, `flatpak install flathub io.github.volkdude85.QuixiDesk` becomes the shortest way
to get QuixiDesk on Linux. Until then this repository's signed remote is the line that works, and the
Flathub package is not something you can install yet.

#### On a machine that has never had Flatpak

The command above cannot install the thing it needs to exist. That is the only prerequisite:

```sh
sudo pacman -S --needed flatpak     # Arch, EndeavourOS, SteamOS
sudo apt install flatpak            # Debian, Ubuntu
sudo dnf install flatpak            # Fedora
```

Then the install line again. **The first install is about 1.4 GB**, because it pulls the
`org.gnome.Platform` 51 runtime alongside the app itself. Flatpak prints nothing while it downloads, so
a slow connection makes that look like a hang — it is not one; `flatpak ps` shows the transfer if you
want to watch it.

```sh
flatpak list --app --columns=application,version,origin | grep quixi   # did it land
flatpak run io.github.volkdude85.quixidesk                              # start it
```

If the disk is full, `pacman` refuses before any of this with a free-space error; on a nearly full root,
`sudo paccache -rk1` typically returns several gigabytes of package cache first.

### The window fits the deck

Upstream opens at 1280x840 logical. A Steam Deck in desktop mode is 1280x800, so the window was forty
pixels taller than the screen and the composer sat below the bottom edge where nothing scrolls to it.
Patch `0099-window-fits-the-screen` clamps the default to the monitor it opens on: measured **1240x720**
on a 1280x800 display, bottom edge visible. On anything larger than 1280x840 nothing changes.

### Artwork for the Game Mode shortcut

Steam will happily show a generic grey tile for a non-Steam app. `steam/` carries the shapes Steam
looks for, cut from the app's own mark and colours:

| file | where it goes |
|---|---|
| `steam/grid-460x215.png` | library capsule (horizontal) |
| `steam/grid-600x900.png` | library capsule (portrait) |
| `steam/hero-1920x620.png` | hero banner |
| `steam/logo-1280x720.png` | logo overlay |
| `steam/icon-512.png` | shortcut icon |

Right-click the shortcut in Steam → **Properties** → drop each one into its slot. No account, no
SteamGridDB upload, nothing to install.

### The tile puts itself in the library

`install.sh` on a Deck also writes the shortcut into Steam's own list and drops the artwork where
Steam looks for it, so the app shows up in Game Mode as a proper tile — no Add a Non-Steam Game, no
right-click, no four images by hand.

It edits `userdata/<id>/config/shortcuts.vdf`, so it is careful in a specific way: it walks the
structure rather than counting trailing terminators, it inserts the new entry where the last one
ends so every existing byte keeps its position, it parses the result and refuses to write unless both
the old entries and the new one come back intact, it backs the file up first, and it refuses to run
while Steam is open, because Steam rewrites that file on exit. Artwork goes to
`userdata/<id>/config/grid/<appid>_p.png` and friends.

By hand, if you would rather:

```sh
python3 scripts/deck-steam-shortcut.py            # say what it would do
python3 scripts/deck-steam-shortcut.py --write    # do it
```
