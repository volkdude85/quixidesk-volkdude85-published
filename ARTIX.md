# Artix / OpenRC

This package is built and tested on Arch with systemd. Artix should work, and this document explains
what was actually checked versus what is still unverified — because "should work" is not the same as
"tested", and dressing one up as the other is how people waste an evening.

**Status: builds on Artix (dinit).** Built end-to-end in `artixlinux/artixlinux` with no systemd present —
all thirteen patches applied, `build()`, `check()` and `package()` all completed, producing a 30.6 MB
package with **118 entries**, the same file count as the Arch build and 0.1% smaller (dependency
version drift, not a difference in content).

Still untested: actually **running** the desktop on a live Artix session, and the other three inits
(runit, s6, OpenRC). See the matrix below for what is proven versus what is expected.

## What was checked, and how

### The platform layer makes no systemd calls

This was the main worry, so it was audited rather than assumed. Grepping the entire platform crate for
`systemctl`, `logind`, `org.freedesktop.login1`, `sd_notify`, and `systemd` returns **two hits, both of
them comments** — one explaining why the code refuses to trust environment variables blindly, one
describing a failure mode. No code path calls systemd.

### Every D-Bus name it talks to is a desktop service, not an init service

```
org.freedesktop.DBus                      org.kde.KWin.ScreenShot2
org.freedesktop.portal.Desktop            org.gnome.Mutter
org.freedesktop.portal.FileChooser        org.gnome.Mutter.DisplayConfig
org.freedesktop.portal.Screenshot         org.gnome.Shell
org.freedesktop.portal.Request            org.gnome.Shell.Extensions.Windows
org.freedesktop.impl.portal.PermissionStore   org.xfce.Xfconf
```

All of these are provided by the desktop environment or by `xdg-desktop-portal`, on a plain D-Bus
session bus. Artix ships a standard `dbus-daemon` (or dbus-broker) and the session bus works the same
way. `elogind` provides the logind interfaces if anything ever needs them; nothing here does.

### Not one dependency is systemd-specific

| dependency | repo | available on Artix |
|---|---|---|
| glibc, gcc-libs, glib2, openssl, bash, dbus | core | yes — mirrored |
| gtk3, webkit2gtk-4.1, pango, cairo, gdk-pixbuf2, libsoup3, hicolor-icon-theme, libpulse | extra | yes — mirrored |

Artix replaces the systemd-dependent packages in Arch's repos; none of the fourteen above is one of
them. The PKGBUILD contains no `systemctl` calls, no `.install` hooks that touch services, and no
`systemd-tmpfiles` entries.

## `0013-artix-love` — what a cold build actually required

*"I don't want to run it, but I want to love it."*

That is the whole rationale for this work, and the patch is named after it rather than after the bug it
fixes.

The suite would not pass in an Artix container, and the cause had nothing to do with init systems. A
test asserted that a mouse move makes the pointer position known **without first checking that this
host can move a mouse at all**. In a container, on CI, or with no `ydotoold` running, the move cannot
happen — so the assertion was really "this machine has a pointer", which is the environment talking
rather than the contract.

It now asks the capability report and asserts something real either way:

| situation | assertion |
|---|---|
| input backend present | after a successful move, the position is known |
| no input backend | the move cannot have happened, so a position must **not** be claimed |

Neither branch is a skip. Without this patch, container CI is impossible for anyone — including the
person whose project this is.


## The OpenRC service, actually run

Not described — executed, on a live Artix system (`NAME="Artix Linux"`, PID 1 is OpenRC's `init`,
`rc-status` showing the `default` runlevel up).

### Where the service file lives, and why not `/usr/share/doc`

The OpenRC service installs to **`/usr/share/quixidesk-custom/ydotoold.openrc`**, not `/usr/share/doc/`.
That is not a style choice.

The Artix base image ships this in `pacman.conf`:

```
NoExtract = usr/share/gtk-doc/html/* usr/share/doc/*
```

So pacman **records the file in its database and then never writes it to disk**. Installing to
`/usr/share/doc` produced a package that reported success, whose `-Ql` claimed to own the path, and
which had no service file anywhere on the system. `pacman -Qkk` was the only thing that surfaced it:

```
warning: quixidesk-custom: /usr/share/doc (No such file or directory)
```

A functional file in a documentation path is invisible exactly where it is needed most. Verified after
the move — a real install leaves the file on disk, and the service starts from it:

```
* Starting ydotoold ... [ ok ]
* status: started
srw------- 1 1000 1000 /run/ydotoold.socket
1562 /usr/bin/ydotoold --socket-path /run/ydotoold.socket --socket-perm 0600 --socket-own 1000:1000
```

Install it with:

```sh
cp /usr/share/quixidesk-custom/ydotoold.openrc /etc/init.d/ydotoold
chmod +x /etc/init.d/ydotoold
echo 'YDOTOOL_OWNER="1000:1000"' >> /etc/conf.d/ydotoold
rc-service ydotoold start
rc-update add ydotoold default
```

`ydotool` is **not in any Artix repository** (checked `system`, `world`, `galaxy`, and `pkgfile`).
It has to come from the AUR or be built from source. The package therefore ships the service file but
treats `ydotool` as an optional dependency, exactly as it does on Arch.

With the real `ydotoold` binary installed and `/dev/uinput` available:

```
* Starting ydotoold ... [ ok ]
* status: started
srw------- 1 root root /run/ydotoold.socket
713 /usr/bin/ydotoold --socket-path /run/ydotoold.socket --socket-perm 0600
```

**The socket is root-owned and that is the trap.** The daemon runs as root because `/dev/uinput` needs
it; without an explicit owner the desktop user cannot connect, and the failure surfaces as "permission
denied" on every input call with nothing in the journal. The service supports the documented override:

```sh
echo 'YDOTOOL_OWNER="1000:1000"' >> /etc/conf.d/ydotoold
rc-service ydotoold restart
```

```
* Stopping ydotoold ... [ ok ]
* Starting ydotoold ... [ ok ]
* status: started
srw------- 1 1000 1000 /run/ydotoold.socket
912 /usr/bin/ydotoold --socket-path /run/ydotoold.socket --socket-perm 0600 --socket-own 1000:1000
```

Start, stop, restart, status, socket ownership and cleanup all verified.

### Testing this without installing Artix

`systemd-nspawn` runs a real Artix userspace with its own OpenRC init, which is enough to test init
integration on a box that cannot run VMs (`kvm_amd: SVM not supported by CPU 9` on the test machine —
BIOS-level, not fixable remotely).

```sh
docker create --name artix-export artixlinux/artixlinux:base-openrc /bin/true
docker export artix-export | tar -xC /mnt/btrfs/artix-nspawn
chown -R root:root /mnt/btrfs/artix-nspawn      # docker export writes uid 1000, which makes OpenRC
                                                # refuse its own paths as "unsafe path transition"
systemd-nspawn -D /mnt/btrfs/artix-nspawn --boot --machine artix-love --bind=/dev/uinput
```

A container has no devices, so `ydotoold` exits with `failed to open uinput device: No such file or
directory`. Binding `/dev/uinput` through is what makes the service testable.

Two traps met on the way: `pgrep -f "<pattern>"` matches the shell running the command and kills it —
use `pgrep -x`; and OpenRC keeps a crashed service in its state, so `rc-service ydotoold zap` is needed
before a clean restart.

## The one thing that needs a daemon

`ydotool` is the only external component that runs as a service, and it is required for **all synthetic
input** — typing, key combos, mouse movement and clicks. Without `ydotoold` running, every input
function returns an error naming the missing socket.

On Arch that is `ydotoold.service`. On OpenRC, use the init script in
[`contrib/ydotoold.openrc`](contrib/ydotoold.openrc):

```sh
sudo cp contrib/ydotoold.openrc /etc/init.d/ydotoold
sudo chmod +x /etc/init.d/ydotoold
sudo rc-update add ydotoold default
sudo rc-service ydotoold start
```

It creates the socket at `/run/ydotoold.socket`. If you put it somewhere else, the layer honours
`YDOTOOL_SOCKET` — but **only if the path actually exists**; a stale or invented path is ignored on
purpose, because honouring a bad path silently kills input with an empty error message.

## What to check once you run it

1. **`capabilities()` first.** The layer exposes a capability probe that reports what this machine can
   actually do — session type, which capture backend will be used, whether input is available, which
   pickers exist. If something is wrong, that call tells you what before you try to use it.
2. **Session type.** Run `loginctl show-session $XDG_SESSION_ID -p Type` — on a Wayland session with a
   compositor KWin/Mutter understand, capture and cursor work differently than on X11. A headless
   session reports `none` and the layer degrades honestly rather than pretending.
3. **The portal.** `xdg-desktop-portal` plus one backend (`-gtk` for most desktops) must be running for
   file pickers and Wayland screenshot capture. Check with `busctl --user list | grep portal`. If the
   pickers do nothing, that is almost always the portal, not this package.
4. **`ydotoold` reachable.** `ls /run/ydotoold.socket` before blaming input.

## Known non-issues you might trip over

- **`xdg-desktop-portal-gnome` failing with "Dependency failed"** — that backend expects GNOME session
   infrastructure. On a non-GNOME desktop it fails harmlessly; the `-gtk` backend is the one in use.
  It shows up as noise in the journal and nothing else.
- **A notification daemon is not a dependency**, but if none is installed, every notification attempt
  fails and some desktops ring the bell each time. Install `xfce4-notifyd`, `dunst` or similar.
- **Screen blanking** defaults to ten minutes on many setups. If the screen goes black with the app
  still running, that is DPMS, not a crash: `xset s off; xset -dpms`.

## If it does not work

The useful report is: the output of `capabilities()`, the session type, whether `ydotoold`'s socket
exists, and the exact error text. That is enough to tell a missing dependency from a missing backend
from a genuine bug. An issue with "doesn't work on Artix" alone cannot be acted on.

## Result: an Artix build, and two bugs it caught

```
=== system ===
NAME="Artix Linux"   ID=artix   systemd present: NO

=== build ===
0001..0008, 0009..0013 ... Passed        (13 patches)
==> Starting build()...  ==> Starting check()...
==> Creating package "quixidesk-custom"...
==> Finished making: quixidesk-custom 3.6556.10-1

30591998 bytes   118 entries
```

The build was not the valuable part. **Two real defects surfaced only because this ran somewhere
clean**, and neither had anything to do with init systems:

1. **`cargo fetch` ran before the patches.** Patch `0001` adds `png = "0.17"` to `Cargo.toml`, so the
   fetch downloaded the *unpatched* dependency set and `build()` then failed offline with
   `no matching package named png found`. It worked on machines whose cargo cache already had `png`.
   A new user's first `makepkg` would have failed. Now fixed: the fetch runs after all patches.

2. **A test asserted this machine has a mouse.** `cursor_position_is_not_claimed_until_known` checked
   that a mouse move makes the pointer position known without first checking the host *can* move a
   mouse. In a container it cannot, so the suite could not pass — which makes container CI impossible
   for anyone. Fixed by `0013-artix-love`.

Neither would have been found by reading the code. Both are the same class: code assuming the
environment it was written on.
