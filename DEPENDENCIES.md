# Dependencies

Everything this package needs, why, and how that was established. Nothing here is guessed from the
PKGBUILD's own arrays — the linked libraries were read off the shipped binaries, and the spawned
tools were read out of the source.

## Hard runtime dependencies

Installed by `pacman -U` automatically.

| package | why | how it was verified |
|---|---|---|
| `glibc` | `libc.so.6`, `libm.so.6`, `ld-linux` | DT_NEEDED |
| `gcc-libs` | `libgcc_s.so.1` | DT_NEEDED |
| `gtk3` | `libgtk-3.so.0`, `libgdk-3.so.0` | DT_NEEDED |
| `webkit2gtk-4.1` | `libwebkit2gtk-4.1.so.0`, `libjavascriptcoregtk-4.1.so.0` — the entire UI is a webview | DT_NEEDED |
| `glib2` | `libglib-2.0`, `libgobject-2.0`, `libgio-2.0` | DT_NEEDED |
| `pango` | `libpango-1.0.so.0` | DT_NEEDED |
| `cairo` | `libcairo.so.2`, `libcairo-gobject.so.2` | DT_NEEDED |
| `gdk-pixbuf2` | `libgdk_pixbuf-2.0.so.0` | DT_NEEDED |
| `libsoup3` | `libsoup-3.0.so.0` | DT_NEEDED |
| `bash` | the agent's shell tool runs `/bin/bash` | `("bash", "bash", "/bin/bash")` in the workspace crate |
| `dbus` | session bus: KWin `ScreenShot2`, the XDG portal, and Secret Service all go over it | required at runtime, not linked |
| `libpulse` | `paplay` plays the WAV the TTS backend returns — read-aloud is silent without it | `Command::new("paplay")` in `voice.rs` |
| `hicolor-icon-theme` | the icon directories the launcher's `Icon=quixidesk` resolves against | data, not code |
| `openssl` | **nothing uses it** — see "Declared but unused" below | not linked, not spawned |

## Optional dependencies, by capability

Install the row for your desktop. The app probes for these and reports what is missing rather than
failing silently.

| capability | package | without it |
|---|---|---|
| screen capture on **KDE** | *(none)* | nothing — capture is `org.kde.KWin.ScreenShot2` in-process, no external tool |
| screen capture on GNOME | `gnome-screenshot` | no capture |
| screen capture on wlroots (Sway, Hyprland) | `grim` | no capture |
| screen capture on XFCE | `xfce4-screenshooter` | falls back to `import` |
| screen capture on Cinnamon | `cinnamon-screenshot` | falls back to `import` |
| any capture fallback | `imagemagick` (`import`) | no fallback path |
| synthetic input — typing, keys, mouse | `ydotool` **and** a running `ydotoold` | every input call returns an error naming the missing socket |
| clipboard on Wayland | `wl-clipboard` | no clipboard |
| clipboard on X11 | `xclip` (or `xsel`) | no clipboard |
| file / folder pickers on KDE | `kdialog` | no picker |
| file / folder pickers elsewhere | `zenity` | no picker |
| display listing on KDE | `kscreen` (`kscreen-doctor`) | no display list |
| display listing on X11 | `xorg-xrandr` | no display list |
| display listing on wlroots | `wlr-randr` | no display list |
| window under cursor on X11 | `xdotool` | reported as unknown |
| launching applications | `kio` (`kioclient6`) | falls back to the parsed `Exec` line |
| **reverse engineering** | `ghidra` (and its Java runtime) | the skill is present but cannot run |
| credentials in the OS keyring (opt-in via `QUIXI_USE_KEYRING=1`) | `gnome-keyring` or `kwallet` | by default credentials use a local key file and this is not needed |
| git panels | `git` | those features are hidden |

## Services this edition expects — not packages

These are what the app talks to rather than what it links against. They are not in `depends` because
they are not in any repository.

| service | default endpoint | what it powers |
|---|---|---|
| Kokoro TTS | `http://127.0.0.1:8765` | read aloud. `quixi --voice` shows the configuration; `quixi --say "text" --dry-run` proves the round trip |
| streaming STT | `http://127.0.0.1:8791` | dictation. `quixi --transcript` prints what the service has accumulated |
| a local model server | e.g. `http://127.0.0.1:8086/v1` | any provider you point at it; without one, use a cloud provider |
| a Chromium browser, or Firefox + `geckodriver` | — | the `browser-driving` skill |
| Ghidra | `/opt/ghidra` or `$GHIDRA_HOME` | the `reverse-engineering` skill |

Configure them in `~/.quixi/voice.json` and the app's provider settings. All are optional: with none
of them the app still runs, and the capability probe reports what is unavailable.

## Build dependencies

`cargo`, `rust`, `pkgconf`, `librsvg` (renders the icon set at package time).

## Declared but unused

`openssl` is in the package's `depends` and nothing needs it: no shipped binary lists `libssl` or
`libcrypto` in DT_NEEDED, and no crate in the tree spawns `openssl`. TLS comes from a statically
linked Rust stack. It is harmless to have installed and is a candidate to drop at the next version.

## Checking it yourself

```sh
# what the binaries actually link
objdump -p /usr/lib/quixidesk/resources/QuixiDesk | awk '/NEEDED/{print $2}'

# what the package declares
tar xOf quixidesk-custom-*.pkg.tar.zst .PKGINFO | grep -E '^depend'

# what this session can actually do
quixi --capabilities
```
