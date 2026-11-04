# Running this on a distribution that is not Arch

Arch and everything built on it is the primary target: the package is a `PKGBUILD`, the dependencies
are named in `pacman`'s vocabulary, and Garuda, EndeavourOS, CachyOS, Manjaro, Artix and SteamOS all
resolve the same names.

Debian and its children are the second target. Nothing in the app assumes `pacman`, and the code
already probes for a tool instead of assuming it is installed — the only thing that differed was the
NAME of the package and the command that installs it. That is now carried in the binary: every
capability note ends with the install line for the family underneath, read off `/etc/os-release`
(`ID` first, then `ID_LIKE`, so a derivative resolves without a list of distro names to maintain).

```sh
quixi --capabilities
# ...
# "Install ydotool and start ydotoold for cursor and keyboard synthesis. … On Debian: `sudo apt install ydotool`."
```

## Devuan, and the Lunduke Computer OS

Devuan is Debian with the systemd parts taken out, and LCOS is built on Devuan. Both resolve to the
Debian package names above and to `apt`, so nothing about the install changes — but the family is named
separately in the report, because telling a Devuan user their machine is "Debian" reads like the app
guessed. Detection is `ID=devuan`, or `ID=lcos`, or `ID_LIKE` containing `devuan`.

Nothing in this app needs systemd: there is no unit in the package, and the daemon page reports on
services instead of managing them.

## BSD

FreeBSD, OpenBSD and NetBSD are a **port, not a package** — this is the honest status:

* the toolkit is available in ports (GTK3, WebKitGTK 4.1, librsvg, pkg-config), so the libraries the
  binary links exist;
* `tao` and `wry` — the window and webview layers this app is built on — do not list any BSD as a
  supported target, so the first step is getting those to build, not getting this to build;
* the platform layer in `crates/quixi-platform/src/linux.rs` is `cfg(target_os = "linux")`, and the
  tools it drives (`ydotool`, `wl-clipboard`, `spectacle`, `grim`) have no BSD counterparts. Screenshot,
  clipboard and input synthesis would each need their own implementation.

What exists today is the reporting half, so a BSD build does not lie about what it can do: the family is
detected from the target at compile time (a BSD has no `/etc/os-release` to read), the package manager
is named — `pkg install`, `pkg_add`, `pkgin` — and every capability hint says there is no packaged
equivalent yet rather than inventing a name.

Not tested on hardware. Nothing here should be read as "BSD is supported".

## Linked libraries, by family

| Arch | Debian / Ubuntu | Fedora | openSUSE | why |
|---|---|---|---|---|
| `glibc` | `libc6` | `glibc` | `glibc` | `libc.so.6` |
| `gcc-libs` | `libgcc-s1` | `libgcc` | `libgcc_s1` | `libgcc_s.so.1` |
| `gtk3` | `libgtk-3-0` | `gtk3` | `gtk3` | the window |
| `webkit2gtk-4.1` | `libwebkit2gtk-4.1-0` | `webkit2gtk4.1` | `libwebkit2gtk-4_1-0` | the entire UI is a webview |
| `glib2` | `libglib2.0-0` | `glib2` | `libglib-2_0-0` | `libglib-2.0`, `libgio-2.0` |
| `pango` | `libpango-1.0-0` | `pango` | `libpango-1_0-0` | text |
| `cairo` | `libcairo2` | `cairo` | `libcairo2` | drawing |
| `gdk-pixbuf2` | `libgdk-pixbuf-2.0-0` | `gdk-pixbuf2` | `libgdk_pixbuf-2_0-0` | images |
| `libsoup3` | `libsoup-3.0-0` | `libsoup3` | `libsoup-3_0-0` | HTTP from the webview |
| `dbus` | `libdbus-1-3` | `dbus-libs` | `libdbus-1-3` | ScreenShot2, portals, Secret Service |
| `libpulse` | `libpulse0` | `pulseaudio-libs` | `libpulse0` | `paplay` for read-aloud |
| `hicolor-icon-theme` | `hicolor-icon-theme` | `hicolor-icon-theme` | `hicolor-icon-theme` | the launcher icon |

## Optional tools, by family

| Arch | Debian / Ubuntu | Fedora | openSUSE | capability |
|---|---|---|---|---|
| `ydotool` | `ydotool` | `ydotool` | `ydotool` | typing, key combos, mouse (needs `ydotoold`) |
| `wl-clipboard` | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` | clipboard on Wayland |
| `xclip` / `xsel` | `xclip` / `xsel` | `xclip` / `xsel` | `xclip` / `xsel` | clipboard on X11 |
| `kdialog` / `zenity` | same | same | same | native file pickers |
| `imagemagick` | `imagemagick` | `ImageMagick` | `ImageMagick` | capture fallback (`import`) |
| `spectacle` | `spectacle` | `spectacle` | `spectacle` | capture on KDE (the ScreenShot2 D-Bus path needs nothing) |
| `grim` | `grim` | `grim` | `grim` | capture on wlroots (Sway, Hyprland) |
| `gnome-screenshot` | `gnome-screenshot` | `gnome-screenshot` | `gnome-screenshot` | capture on GNOME |
| `xfce4-screenshooter` | `xfce4-screenshooter` | `xfce4-screenshooter` | `xfce4-screenshooter` | capture on XFCE |
| `kscreen` | `kscreen` | `kscreen` | `kscreen` | display enumeration on KDE |
| `xorg-xrandr` | `x11-xserver-utils` | `xrandr` | `xrandr` | display enumeration on X11 |
| `wlr-randr` | `wlr-randr` | `wlr-randr` | `wlr-randr` | display enumeration on wlroots |
| `xdotool` | `xdotool` | `xdotool` | `xdotool` | cursor position, X11 window operations |
| `git` | `git` | `git` | `git` | workspace features |
| `ghidra` | `ghidra` | `ghidra` | `ghidra` | the reverse-engineering skill |

Two names above are the ones that actually differ between families and bite people: `xorg-xrandr` is
`x11-xserver-utils` on Debian, and `imagemagick` is capitalised on Fedora and openSUSE.

## Build dependencies, by family

| Arch | Debian / Ubuntu | Fedora | openSUSE |
|---|---|---|---|
| `cargo`, `rust` | `cargo`, `rustc` | `cargo`, `rust` | `cargo`, `rust` |
| `pkgconf` | `pkg-config` | `pkgconf` | `pkg-config` |
| `librsvg` | `librsvg2-dev` | `librsvg2-devel` | `librsvg-devel` |
| `gtk3` | `libgtk-3-dev` | `gtk3-devel` | `gtk3-devel` |
| `webkit2gtk-4.1` | `libwebkit2gtk-4.1-dev` | `webkit2gtk4.1-devel` | `libwebkit2gtk-4_1-devel` |
| `libsoup3` | `libsoup-3.0-dev` | `libsoup3-devel` | `libsoup-3_0-devel` |

## SteamOS

Arch-based, so every package name above resolves — but the root filesystem is immutable and `pacman`
refuses to install into it. SteamOS is covered in `STEAMDECK.md`; the short version is that the app
belongs in the user's home or a Flatpak, not in `/usr`.

## Distros that are neither

Alpine (musl), NixOS, and anything without glibc will need a rebuild of the binary against its own C
library. The app has no dependency on a specific init system — there is no systemd unit in the package
and nothing calls `systemctl` except the daemon page, which reports rather than manages.
