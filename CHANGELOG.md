# Changes

What each release changes, and which patch does it. No narrative — the commits carry that.

> Releases 10 through 30 were built, installed and run, and never written up here. The commit history
> and the prose header on each patch carry them; this file resumes at 31 rather than inventing a
> retrospective.

## 3.6556.12-32

- **The composer button that could only open an empty dialog** (`0050`) — "Add MCP context" browsed
  `resources` and `prompts`, and it skips built-in adapters by design. All six built-ins in this
  build answer `-32601 method not found` to both, so the dialog could only say "Configure an MCP
  server in Tools & skills". It now renders only when a non-built-in server exists to browse, and
  its glyph is a link rather than a struck-through pencil that read as "disabled".

## 3.6556.12-35

**`0055-browser-choice`** — which browser an external link opens in is now a setting instead of a
hardcoded word.

- The catalogue is the desktop's own menu: every `.desktop` entry with `Categories=…WebBrowser…`,
  read from `/usr/share/applications`, `/usr/local/share/applications`, `$XDG_DATA_HOME` and
  `$XDG_DATA_DIRS`. A browser this source has never heard of appears because the desktop says it
  exists, which is how FireDragon and Mullvad Browser get listed at all.
- Each entry is labelled by how it can be driven: **CDP** for the Chromium family, **WebDriver** for
  the Firefox family. "Not drivable" was the old answer for Firefox and it was wrong — different
  wire, same capability.
- Three kinds of answer in the picker, all legitimate: **system default** (what stock QuixiDesk does
  — `xdg-open`), **ask each time** (a chooser per link, and dismissing it opens nothing), or a named
  browser.
- `open-external` accepts a `browser` in the request body, so the chooser's answer takes the same
  path as the setting. A `.desktop` id launches through `gio` so the entry's own `Exec=` is used;
  `system` short-circuits to `xdg-open`; a Chromium still gets `--app=` so the page arrives as its
  own window rather than a tab in a session already open.

The dropdown sits in the browser pane's header, where the panel used to hardcode a name in three
places ("Open in Brave", "Pages open in Brave"), and in Settings → General → Browser.

## 3.6556.12-31

Two things the tool was claiming about itself that were not true.

- **A socket file is not a running daemon** (`0048`) — `quixi --capabilities` reported
  `input_synthesis: true` on a box where ydotoold was not running: the probe used `Path::exists()`,
  and a unix socket leaves its inode behind when the process dies. The probe is now a connect, so it
  cannot advertise a daemon that is not answering, and a test binds a listener, drops it, and asserts
  the file survives while the socket reads as dead.
- **The MCP panel listed a server that cannot work here** (`0049`) — `applescript` is a macOS
  capability and every call against it failed, which reads as "MCP does not work on Linux". The
  seeding loop already skipped it on Linux, but an entry written by an earlier run stayed on disk.
  It is swept from the existing config now; only the built-in adapter is touched, never a server the
  user defined.

## 3.6556.12-9

Appearance and surfaces.

- **Retro theme** — near-black green palette with a phosphor accent, shipped as the default on the
  volkdude85 edition
- **Custom colours** — hue / saturation / lightness sliders, a hex field and a live swatch, replacing
  the native colour input that has no saturation control and commits on first touch
- **Colour overrides stay in their theme** — a custom colour no longer leaks onto every theme chosen
  afterwards
- **Resizable sidebar** — drag handle with keyboard nudge, width stored as a preference
- **Surface options** — boxed surfaces and translucent panels, both switches in Settings

## 3.6556.12-8

- **Readable secondary text** — muted, border and raised tones lifted so labels, helper text and
  borders are visible against the dark shell instead of collapsing into it
- headings use the accent colour rather than body white

## 3.6556.12-7

- **Custom colours apply only to the Custom theme** (the fix above, released separately first)

## 3.6556.12-6

- **Persona file** — `<data-dir>/persona.md`, read at the start of every turn, named in the top bar
  and editable from a page in Settings
- **macOS habits removed from the Linux build** — the prompt no longer suggests `open -a` or
  `osascript`, and shortcut hints no longer render the Command glyph

## 3.6556.12-5

- **Persona support** — the engine reads a persona file and prepends it to the system prompt

## 3.6556.12-4

- **Dictation fixed** — a scope error made every Dictate click throw before doing anything on Linux,
  where no webview recogniser exists. One function, two arguments.
- **Appearance as backend state** — theme and font live in preferences, not only in the window

## 3.6556.12-3

- dictation transport moved onto the existing IPC bridge instead of a private HTTP path

## 3.6556.12-2

- bundled skills, CLI usage text, memory, voice, themes

## 3.6556.12-1

First packaged release: platform support, patch series, CI, packaging.

---

## Patch series

| patch | what it does |
|---|---|
| `0001` | Linux platform layer |
| `0002` | local overrides for this edition |
| `0003` | condensed fallback behaviour |
| `0004` | bundled skills and the skill tool |
| `0005` | headless mode and credentials |
| `0006` | durable memory, wing / room / drawer |
| `0007`,`0008` | voice stack |
| `0009`,`0010` | key handling fixes |
| `0011`,`0012` | test portability and KDE scenario pinning |
| `0013`,`0014` | Artix and Hyprland support |
| `0015` | browser-driving skill |
| `0016` | container-safe tests |
| `0017` | CLI usage text |
| `0018` | themes and fonts |
| `0019` | reverse-engineering skill |
| `0020`,`0021` | voice over IPC, and the dictation scope fix |
| `0022`–`0027` | appearance, persona, palette, contrast, surfaces |
