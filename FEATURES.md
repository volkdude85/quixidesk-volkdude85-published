# Feature matrix

Three states, side by side: what stock QuixiDesk does on Linux, what this packaging adds, and what the
other edition adds on top. Everything below is in the patches, not planned — if a row says a thing
exists, the patch that makes it exist is named.

Read the columns as:

- **stock** — upstream `v3.6556.12` with no patches. On macOS this is the whole product; on Linux
  most of this column is a silent no-op, which is the reason the other two columns exist.
- **arch edition** — [`quixidesk-arch`](https://github.com/volkdude85/quixidesk-arch), 28 patches,
  the restrained build.
- **volkdude85 edition** — [`quixidesk-volkdude85-published`](https://github.com/volkdude85/quixidesk-volkdude85-published),
  106 patches, the same base plus a memory system, a wired voice stack, lifted limits, themes, and a
reverse-engineering skill.

(Counts are `ls *.patch | wc -l` at each repository's root. The series grows; the number here is a
snapshot, not a promise.)

## Desktop integration

| capability | stock on Linux | arch edition | volkdude85 edition |
|---|---|---|---|
| screen capture, full frame | macOS only | ✅ KWin `ScreenShot2` in-process — 29 ms vs ~921 ms through `spectacle` | same |
| screen capture, region | macOS only | ✅ same path, cropped | same |
| capture fallback chain | — | ✅ portal → gnome-shell → spectacle → grim → xfce4-screenshooter → cinnamon-screenshot → gnome-screenshot → import | same |
| active output name | — | ✅ `org.kde.KWin.activeOutputName`, or Mutter's primary flag, or `wlr-randr` | same |
| clipboard read/write | macOS only | ✅ `wl-copy`/`wl-paste` on Wayland, `xclip`/`xsel` on X11 | same |
| synthetic input — type, key combos, mouse | macOS only | ✅ `ydotool` via `ydotoold`, evdev codes, session-aware delay (`-d 25` on Wayland, `-d 0` on X11) | same |
| file and folder pickers | macOS only | ✅ `kdialog` → `zenity` | same |
| display enumeration | macOS only | ✅ `kscreen-doctor` / `xrandr` / `wlr-randr` | same |
| window under cursor | macOS only | ✅ X11 via `xdotool`. On Wayland it answers "unknown" — there is no client-facing window list, the portal does not expose one by design, and `KWin.queryWindowInfo` blocks waiting for a click | same |
| application launching | macOS only | ✅ parsed `.desktop` `Exec`, spawned in-process | same |
| cursor position | macOS only | ✅ `xdotool` over XWayland, Hyprland socket, honest "unknown" otherwise | same |
| keyboard shortcut listing | macOS only | ✅ 231 bindings in 14 ms (one bulk `gsettings list-recursively`; 539 ms and 25 bindings before), XFCE over `Xfconf` D-Bus | same |
| capability probe | — | ✅ `capabilities()` + `quixi --capabilities` | same |
| honest failure | ❌ silent no-ops | ✅ every call returns an error naming the missing tool | same |

## Engine and agent

| capability | stock | arch edition | volkdude85 edition |
|---|---|---|---|
| headless driver (`quixi`, no window) | ❌ | ✅ `--skills`, `--skill`, `--search`, `--providers`, `--prompt-block`, `--capabilities`, `--json` | ✅ same, plus `--memory`, `--remember`, `--recall`, `--voice`, `--say`, `--transcript` |
| skills library + searchable index | ❌ (bundled prompt block only) | ✅ discovers `SKILL.md`, `ListSkills`/`LoadSkill` tools, paginated 50-per-page index | same |
| voice — read aloud / dictation | webview Web Speech API | ✅ engine-side: Kokoro-style HTTP TTS or a command; streaming `/state` STT or a command. **Defaults off** | ✅ same code, wired to a local Kokoro/Whisper stack, **on by default** (`af_heart`) |
| memory | single `memory/MEMORY.md`, injected whole, no search | ❌ unchanged | ✅ wings → rooms → drawers on disk, searchable, scoped |
| context compaction fallback | aborts when the summariser fails | ✅ mechanical handoff instead | same |
| agent rounds | 100 | ❌ unchanged | ✅ 1000 |
| subagents per turn | 4 | ❌ unchanged | ✅ 32 |
| child rounds | 12 | ❌ unchanged | ✅ 200 |
| shell timeout | 3600 s | ❌ unchanged | ✅ 86 400 s |
| attachments / MCP frames | 8 files, 16 MiB | ❌ unchanged | ✅ 64 files, 256 MiB |
| interface theme | Light / Dark / System only | ❌ unchanged | ✅ **matrix** (`#00ff41` phosphor), amber, ice, plus font family and text size |
| custom colours | ❌ none | ❌ unchanged | ✅ hue / saturation / lightness sliders, hex field, live swatch — the native colour input commits on first touch and has no saturation control |
| where appearance is stored | `localStorage` in the window | ❌ unchanged | ✅ backend `AppPreferences`, persisted to `<data_dir>/preferences.json`; `localStorage` is only the paint cache |
| reverse engineering | ❌ | ❌ | ✅ Ghidra headless skill: decompile a binary and read the C, with the wrapper that strips Ghidra's noise |
| credential storage | OS keyring (Secret Service) only | ❌ unchanged — a box with no keyring cannot save an API key | ✅ local 32-byte key file by default, `QUIXI_USE_KEYRING=1` opts back into the keyring |

## Platforms, tooling, packaging

| | stock | arch edition | volkdude85 edition |
|---|---|---|---|
| Artix / OpenRC / dinit (non-systemd) | ❌ | ✅ patch + `ydotoold.openrc` | same |
| Hyprland / Omarchy | ❌ | ✅ cursor position from the compositor socket, two detection bugs fixed | same |
| browser-driving skill | ❌ | ✅ Brave/Chromium over CDP, Firefox over WebDriver BiDi, curl last | same |
| which browser opens a link | fixed in the source | ✅ a setting: system default, ask each time, or any browser the desktop lists — labelled CDP or WebDriver | same |
| test portability | tests assert the developer's machine | ✅ fixed — session type, screenshot size heuristic, "ten applications installed", "spectacle or grim" | same |
| Arch package + CI | — | ✅ PKGBUILD, pristine-tarball CI, chain gate, tag → release | same |

## What that means in one line each

- **stock** — an excellent macOS app that does nothing on Linux outside a few generic paths.
- **arch edition** — the same app, genuinely working on Linux, with nothing changed about how much
  rope the agent gets.
- **volkdude85 edition** — that, plus memory that persists and is searchable, voice wired to real
  local models, and every limit that stopped the agent doing the work moved out of the way. It is
  wider open on purpose; `WAIVER.md` in each repository says exactly how.

## Verification, both editions

Same method, same result: every patch in the chain applies to a pristine upstream tarball, **zero
fuzz, zero offset**, workspace built in an `archlinux` container, **58 tests passed**, package
produced and attached to the tag's release. `ci/ci.sh` reproduces it locally in about ten minutes.
