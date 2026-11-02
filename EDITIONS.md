# Two editions of the same packaging

There are two builds of this. They share the same platform layer and the same verification. They are
not the same product.

|  | [`quixidesk-arch`](https://github.com/volkdude85/quixidesk-arch) | [`quixidesk-volkdude85`](https://github.com/volkdude85/quixidesk-volkdude85) |
|---|---|---|
| **what it is** | the build made in the spirit of what Eric would want | **PBBBT** — the edition that runs on one specific machine and does cool shit |
| **who it's for** | anyone on Arch, and Eric first | me. published in case it's useful |
| **patches** | 14 | 50 |
| **memory** ([full comparison](MEMORY-COMPARISON.md)) | upstream: a single `memory/MEMORY.md` read by the UI panel only | MemPalace-shaped: wings → rooms → drawers, searchable, markdown on disk |
| **voice** | local TTS/STT, **defaults off** | wired to my Kokoro/Whisper setup, `af_heart`, on by default |
| **credential storage** | local key file, keyring opt-in | same |
| **limits** | raised, see the waiver | raised the same way |
| **attitude** | restrained; nothing added that upstream would not plausibly accept | unhinged; additions chosen because they do something interesting, not because they are tidy |
| **upstream cleanliness** | patches against the release tarball, upstream tree untouched | identical — neither edition is a fork |

## Which one to pick

- **Arch, general use, or you are Eric:** [`quixidesk-arch`](https://github.com/volkdude85/quixidesk-arch).
  It adds the Linux platform layer and the fixes, and otherwise gets out of the way. Nothing personal
  is baked in.
- **You want to see what a maximally customised local AI desktop looks like, warts included:**
  [`quixidesk-volkdude85`](https://github.com/volkdude85/quixidesk-volkdude85). It is the same base
  with a memory system that persists everything to disk, a voice stack tuned to one specific host, and
  a lot of opinions. PBBBT.

## They do not depend on each other

Both editions patch the upstream `QuixiAI/QuixiDesk` release tarball **directly**. Neither imports the
other, neither fetches from the other, and the patch series are independent:

- `0001`, `0003`–`0005`, `0009`–`0016` — the same changes in both trees, re-cut against each
  edition's own series so the context differs even where the content does not
- `0006-memory` — **volkdude85 edition only**
- `0002-voice` (arch) / `0007-voice` + `0008-voice-local` (volkdude85) — the same feature with
  different defaults

You can clone either one on its own and it builds. Deleting the other repo breaks nothing.

This document lives only in this repository. The Arch edition does not advertise this one, so that a
stranger installing it gets no personal material.

## What is identical in both

Everything that is actual engineering rather than taste:

- the Linux `ComputerUse` platform layer — capture, clipboard, synthetic input, file pickers, display
  enumeration, window lookup, app launching
- the raised limits and the condense fallback that stops them breaking context compaction
- skills directory and a searchable, paginated index exposed as a model tool
- keyboard-shortcut enumeration, normalised across KDE, GNOME and XFCE
- the in-process replacements that were measured as wins (KDE `ScreenShot2` at 29 ms versus ~921 ms
  through `spectacle`; one bulk `gsettings` call at 14 ms versus 539 ms for 25 spawns)
- the test-portability fixes, which are the least glamorous and most valuable thing here — three of
  the four bugs found by running the suite on other machines were tests asserting the *developer's*
  environment rather than the contract
- `ci/`, which is byte-identical in both

## Verification applies to both

57 tests per run, built from a pristine upstream tarball with the patch chain applied, on three
machines:

| machine | CPU | desktop |
|---|---|---|
| AMD 7950X3D | Zen 4 | KDE Wayland |
| Intel i7-12700H | Alder Lake | GNOME Wayland, XFCE X11 |
| AMD 5800X | Zen 3 | XFCE, headless |

Cross-desktop capability matrix: **46 checks, 46 passed** across KDE, GNOME and XFCE, including an
automated file-picker test that needs no human.

## Both are unguarded

Read [`WAIVER.md`](WAIVER.md) before running either one. The limits that would normally bound what the
agent can do have been deliberately raised, and in several places removed. That is a choice, not an
oversight, and it is the same choice in both editions.
