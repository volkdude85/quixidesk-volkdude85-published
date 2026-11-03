# What broke, and what we did about it

A running log of every wall hit while making this edition ship as a Flatpak and behave on a Steam
Deck, with the fix that got past it and whether the fix was verified or only reasoned about. Ordered
by when it bit.

`verified` means it was exercised on this machine and the result was read back. `unverified` means the
fix is in place and the reasoning holds, but nothing has been run to prove it — say so rather than let
it pass as tested.

---

## Packaging

### 1. `Can't find file at quixidesk-src.tar.gz/flatpak-src`

**Symptom** — `flatpak-builder` stops during "Downloading sources".

**Cause** — the manifest still carried a `type: dir` source pointing at `../flatpak-src`, left over
from the previous approach, while the staging script had already rewritten the block to
`type: archive`.

**Fix** — the staging rewrite matches the whole `sources:` block rather than one spelled-out path, so a
stale source cannot survive the rewrite. *(verified)*

### 2. The same source step failing a second time, with the crate files present

**Symptom** — `tar (child): …adler2-2.0.1.crate: Cannot open: No such file or directory`, while the
file demonstrably existed.

**Cause** — nothing to do with the path. The first run was killed mid-download; the retry started with
a partially populated download directory and raced the extractor.

**Fix** — none needed. Re-running once the sources were on disk completed. A lesson, not a patch:
`flatpak-builder`'s download phase is not atomic across a kill. *(verified)*

### 3. The Flathub build container cannot install the Rust SDK extension

**Symptom** — `Delta requires 1.7 GB free space, but only 894.1 MB available`.

**Cause** — `ghcr.io/flathub-infra/flatpak-github-actions:gnome-50` has a small filesystem and
`org.freedesktop.Sdk.Extension.rust-stable` is 1.7 GB.

**Fix** — the binary is compiled on the runner with a normal toolchain and the manifest packages it as
`prebuilt/QuixiDesk`; the sandbox only installs files. A packager that compiles is a packager that can
fail on a toolchain. The *Flathub submission* keeps the source build (their builders have the room,
and their rules require it). *(verified — CI green)*

### 4. `flatpak-builder: not found` once the job left the container

**Cause** — the container image provides the tooling; a plain runner does not.

**Fix** — `apt-get install flatpak flatpak-builder`, plus `flathub` remote added as root. *(verified)*

### 5. `Flatpak system operation Deploy not allowed for user`

**Cause** — the action runs `flatpak --system install` as the runner user; the system helper refuses.

**Fix** — install `org.gnome.Platform//50` and `org.gnome.Sdk//50` as root *before* the action looks for
them. *(verified)*

### 6. `install: cannot stat 'flatpak/quixidesk-flatpak'`

**Cause** — the packaging files live in this repository, not in the application tree that CI prepares
from the upstream tarball.

**Fix** — CI copies `flatpak/` into the prepared tree, exactly as `build-flatpak.sh` does locally.
*(verified)*

### 7. `Failed to execute child process "eu-strip"`

**Cause** — `flatpak-builder` strips binaries and the runner has no `elfutils`.

**Fix** — added to the apt line. *(verified)*

---

## Flathub linter

### 8. `finish-args-portal-talk-name`

**Cause** — `--talk-name=org.freedesktop.portal.Desktop`. The portal bus is already reachable from
inside the sandbox, so asking is both redundant and an error.

**Fix** — removed. `org.kde.KWin` and `org.kde.KWin.Scripting` stay: those are not portal bus names and
are what the capture path uses. *(verified — build passed)*

### 9. `unknown-tag`, `content-rating-missing`, `metainfo-missing-screenshots`

**Cause** — three in one file. The element is `<content_rating type="oars-1.1">`, singular; I wrote
`<content_ratings>`, so AppStream saw an unknown tag *and* no age rating. Separately, a repository-level
check wants at least one screenshot.

**Fix** — singular element with the OARS attributes, plus a `<screenshots>` block. Verified with
`appstreamcli validate` **inside the built sandbox** before pushing: "✔ Validation was successful".
*(verified)*

### 10. `runtime-update-available-to-org.gnome.Platform-51`

**Cause** — warning, not an error: the manifest asked for 50 while 51 exists.

**Fix** — bumped to 51 with the rust-stable 26.08 extension, rebuilt locally first, binary 26,985,152
bytes, appstream still clean, then pushed. *(verified)*

---

## Steam Deck behaviour

### 11. The window is taller than the screen

**Symptom** — on a 1280x800 display the window came up **1280x840**: forty logical pixels taller than
the panel, with the composer and Send button below the bottom edge, where no window manager scrolls.

**Cause** — upstream hard-codes `LogicalSize::new(1280.0, 840.0)`.

**Fix** — patch `0099-window-fits-the-screen` clamps the default to the monitor's logical size, less
room for a panel and titlebar. Measured after: **1240x720**, bottom edge visible, nothing clipped. On
panels larger than 1280x840 nothing changes. *(verified)*

### 12. Under a Game Mode compositor the window floats in black

**Symptom** — nested `gamescope -W 1280 -H 800` running the app: the window is correct and uncropped,
but it sits in a black field rather than filling the frame, because Game Mode gives one application the
whole display and does not decorate or maximize it.

**Fix attempted** — the window builder also asks to be maximized when the panel is handheld-sized
(`width <= 1366 && height <= 900`). A desktop window manager honours the same hint.

**Status — UNVERIFIED, and the harness cannot settle it.** Tracked as
[issue #1](https://github.com/volkdude85/quixidesk-volkdude85-published/issues/1) so it closes on
evidence rather than on a paragraph in a markdown file.

What was actually measured, twice, on this machine:

| run | result |
|---|---|
| before the maximize hint | window 1240x720 at 1:1, black borders on all four sides |
| after the maximize hint | content occupies 1280x743 of the 800-pixel frame — 1240x720 scaled up to fit the width, leaving ~28 px black at top and bottom. The hint does not resize the window; gamescope has no window manager to honour it, so it scales instead. |

And the second run rendered a blank dark rectangle — no sidebar, no composer — while the identical
binary had drawn the full UI twenty minutes earlier in the same harness. That is the harness, not the
app: **this box is NVIDIA, a Deck is AMD**. Nested gamescope on the proprietary driver throws
`vkGetPhysicalDeviceFormatProperties2 returned zero modifiers` and renders inconsistently, so nothing
this machine says about Game Mode rendering can be trusted either way.

What would actually settle it: a Deck, Steam closed, `sh install.sh`, then Game Mode. Until that
happens this stays on the unverified list, and the honest expectation is that a maximized window fills
an AMD compositor that has a window manager's worth of behaviour, and that the letterboxing above is an
artifact of nesting.

### 12a. The test harness is not the target

Worth writing down because it has already produced one wrong conclusion: an app that renders blank
inside nested gamescope on NVIDIA may be perfectly fine on gamescope on AMD, and vice versa. Every
measurement that depends on the compositor is a measurement of *this* compositor. Geometry measured
from an X server (`xwininfo`) is reliable; anything about what got painted is not.

### 13. `Address already in use (os error 98)`

**Cause** — the app binds a loopback port for its automation bridge. A second instance conflicts with
the first.

**Fix** — `QUIXI_AUTOMATION_PORT=<port>`, or close the running instance first. Worth knowing because it
reads as "the app is broken" rather than "the app is already running". *(verified)*

### 14. The sandbox cannot carry `ydotool` or `wl-clipboard`

**Cause** — both are host binaries. `ydotoold` in particular needs root and a `uinput` device; a Flatpak
cannot provide either for you.

**Consequence** — in the Flatpak, input synthesis and clipboard read/write are the pieces that need
permissions or that simply do not work. Steam capture goes through the KDE portal and does work.

**Fix** — the distrobox route (`scripts/steamdeck-distrobox.sh`) installs both inside a container that
lives in your home and survives SteamOS updates. Documented in `STEAMDECK.md` as Route A.
*(route documented and its dependencies exercised in an earlier session; not re-run today — unverified)*

---

## Steam integration

### 15. A shortcut's appid is not derived from anything

**Finding** — Valve's non-Steam shortcut ids do not reproduce from `crc32(exe + name)` or any variant
tried against the two shortcuts already on this machine. They are assigned, not computed.

**Consequence** — the shortcut tool picks an id, writes it, and names the grid artwork after the number
it wrote. The file is the source of truth; the artwork has to follow it. *(verified against two real
entries)*

### 16. `shortcuts.vdf` ends in more terminators than the nesting implies

**Symptom** — appending before the final `0x08` put the new entry *inside* the previous one, and a naive
`sliced data[:-1]` corrupts the file.

**Cause** — the file ends in a run of object terminators, and Steam leaves an extra.

**Fix** — walk the structure and insert where the last entry actually ends. The tool then re-parses the
result and refuses to write unless the old entries and the new one all come back intact.
*(verified on a copy: 918 → 1,262 bytes, all three entries parse, second run is a no-op)*

### 17. `Failed to install bundle: GPG verification enabled, but no signatures found`

**Cause** — once an application's remote has signature checking on, `flatpak install <file>.flatpak`
refuses an unsigned bundle. A bundle built straight from an unsigned build fails even though the same
code installs fine from the signed repository.

**Fix** — import the bundle into the signed repository, `flatpak build-sign`, `flatpak build-update-repo
--gpg-sign=…`, then `flatpak build-bundle` from that repository. CI does the same by importing the
release key from repository secrets.

**Status — workaround known, one unresolved case today**: after importing an unsigned bundle the
sign-then-bundle sequence still produced a bundle the installer rejected. Re-signing the existing
signed commit and rebuilding the repository remains the reliable path.
*(partially verified)*

---

## Working practice

### 18. Screenshots and recordings leak the sidebar

**What happened** — the first demo recording was made against a real profile, so the left rail showed
actual conversation titles in a video destined for a public submission.

**Fix** — `QUIXI_TEST_PROFILE=<absolute path>` and `QUIXI_PALACE_DIR=<absolute path>` give a scratch
profile with an empty history. Both must be **absolute**; a relative path is rejected with
"Test profile must be an absolute path". Re-recorded, and the released asset replaced.
*(verified)*

### 19. OCR on a small screenshot invents typos

The edition label read as `volkdue85` in three separate machine readings of the screenshots. The file —
`resources/edition.txt` — says `(volkdude85 published)`. Small text at low resolution is not evidence;
check the source before reporting a bug.

### 20. Repeated failure means go and read, not try again

Every wall above that took more than one attempt was solved by reading the actual error text, or by
looking the behaviour up, rather than by another guess. The Rust SDK delta, the eu-strip strip step, and
the portal talk-name were all one search each after a wrong theory.

---

## Privacy

### 21. A compiled Python file was tracked, and it carried the build path

**What happened** — `scripts/__pycache__/deck-steam-shortcut.cpython-314.pyc` was committed. A `.pyc`
stores the absolute path of the source it was compiled from, and `strings` on that file returns
`/home/volkdude/Projects/quixidesk-public/scripts/deck-steam-shortcut.py`. It was in the public
repository, fetchable by URL, for a while.

**Why it is the same family as the `target/` problem** — compiled and generated files remember where
they were built. `.gitignore` already excluded `/src/` and `/target/` for exactly this reason; the
Python cache was not covered.

**Fix** — the file is removed, and `__pycache__/` and `*.pyc` are in `.gitignore`. It remains in
history; a path is not worth rewriting a public repository's history over, but it is worth not adding
more. *(verified — the file is gone from the tree; `git ls-files '*.pyc'` is empty)*

### 22. The audit that found it

Three passes over the repository, because they catch different things: the working tree (what a reader
sees today), every blob in history (what a reader sees with `git log`), and filenames. Categories:
names, emails, phone, address, family, court case, credentials and keys; separately, machine paths,
hostnames, LAN addresses and sudo passwords.

What the developer edition came back with:

| result | detail |
|---|---|
| no name, email, phone, address, case number | zero hits across every revision |
| no credentials | no keys, tokens, passwords, private keys |
| commit identity | `volkdude85 <volkdude85@users.noreply.github.com>` only — the GitHub noreply, no personal address |
| no machine detail | zero hits for `/home/volkdude`, the hostname, LAN or Tailscale addresses |
| one surname | `0044-shipped-persona.patch`, the line about the handle never being written "Volk dude" — already public in both editions |
| one path leak | the `.pyc` above |

Audit source: `doxscan.py` in the session scratch — three passes, severity-ranked, exits non-zero when
it finds anything hard.
