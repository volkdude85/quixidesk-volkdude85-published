# Hyprland and Omarchy

Hyprland is a wlroots-based Wayland compositor. **Omarchy is Hyprland** — Arch with an opinionated
stack on top — so supporting one is supporting the other, with one reporting difference.

## What the compositor answers

`hyprctl` returns JSON for everything the platform layer needs. That is unusual on Wayland and worth
stating plainly: most compositors expose nothing to a client about its own cursor or its window list.

| query | gives |
|---|---|
| `hyprctl -j monitors` | outputs with width, height, scale, position, focused flag |
| `hyprctl -j cursorpos` | **the global cursor position** |
| `hyprctl -j clients` | every window: address, title, class, geometry, workspace |
| `hyprctl -j activewindow` | the focused window |

### The cursor position is the real prize

`cursor_position()` returns `None` on Wayland, and that is correct rather than lazy — an earlier
patch documents why. XWayland will answer X queries and hand back a *plausible wrong number*
(measured at the exact centre of the screen, before and after the pointer moved), which a caller
cannot distinguish from a real reading.

Hyprland is the exception. It publishes the compositor's own cursor position, so the honest `None`
becomes an actual reading. No guessing, no XWayland, no permission prompt.

## Detection: three sources, weakest last

The obvious test is `HYPRLAND_INSTANCE_SIGNATURE`, and **on its own it is wrong**.

That variable is exported to the processes the compositor *launches*, so a GUI app started from the
session has it — but an SSH shell, a cron job, or anything started from outside the session does not.
Measured on Omarchy 4.0.1 / Hyprland 0.56.2: the variable is **absent from Hyprland's own
environment**. A check that reads only it reports "no Hyprland" on a machine running Hyprland at that
moment.

This was not found by reading code. It was found by connecting to a real Omarchy box and watching the
backend decline to fire. Resolution order, the same two sources `hyprctl` itself uses:

| order | source | strength |
|---|---|---|
| 1 | `HYPRLAND_INSTANCE_SIGNATURE` | authoritative when set |
| 2 | newest dir under `$XDG_RUNTIME_DIR/hypr/` | authoritative — the compositor writes its signature there |
| 3 | `XDG_CURRENT_DESKTOP` contains "hyprland" | weakest, last resort only |

`hyprctl_json()` passes the resolved signature to hyprctl explicitly, so the answer is identical from
a session app, an SSH shell, or cron.

Verified in the worst case — over SSH with **nothing** set:

```
HYPRLAND_INSTANCE_SIGNATURE  (unset)
XDG_CURRENT_DESKTOP          (unset)
WAYLAND_DISPLAY              (unset)

session_type         wayland (hyprland, omarchy)
cursor_position      Some(1447, 226)          matches hyprctl -j cursorpos exactly
displays()           eDP-2  2560x1600 @ 1.6x  matches hyprctl -j monitors
```

### Why not just trust `XDG_CURRENT_DESKTOP`

Because it is inherited. A Hyprland instance running nested inside KDE inherits `XDG_CURRENT_DESKTOP=KDE`,
and `desktop_is()` treats an empty value as a match for anything. Measured on a nested instance:

```
XDG_CURRENT_DESKTOP          KDE          <- inherited, wrong
HYPRLAND_INSTANCE_SIGNATURE  0aa6745f...  <- the truth
session_type                 wayland (hyprland)
```

The same defect was in the capture chain: a nested Hyprland client selected `kwin-screenshot2`, which
would have captured the **host** desktop rather than the compositor the process belongs to.
`kwin_screenshot2_available()` now yields when a Hyprland instance is running.

## Omarchy is named separately

`session_type` reports `wayland (hyprland, omarchy)` rather than plain `wayland` or plain `hyprland`.

Omarchy 4.x replaced the bar and launcher with **Quickshell** (QML), so the two are genuinely
different stacks around the same compositor. A bug report that says "Hyprland" when the problem is in
Quickshell sends whoever reads it to the wrong place.

## Verified against a real installation

Omarchy 4.0.4 ISO, with 4.0.1 packages installed on disk (1,146 packages):

```
hyprland 0.56.2        omarchy 4.0.1        omarchy-settings 4.0.1
quickshell 0.3.1       hyprtoolkit 0.5.4    hyprpicker 0.4.7
xdg-desktop-portal-hyprland 1.4.1
/usr/bin/omarchy       /usr/bin/hyprctl     /usr/bin/quickshell
```

No waybar, no walker, no mako. Any support written assuming the waybar-era stack is wrong on Omarchy 4.

## Tested live, not from the docs

The backend was developed against a **nested Hyprland instance** running inside a window on the dev
box — a real compositor with a real `hyprctl`, rather than the documentation.

```
cursor_position   Some(0, 0)                       matches `hyprctl -j cursorpos` exactly
displays()        id=0  WAYLAND-1  1280x720 @ 2x   from the compositor's own list
```

`examples/platform_probe` ships so the same check can be run on any compositor:

```sh
XDG_RUNTIME_DIR=/run/user/1000 \
HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr/ | head -1) \
cargo run --release --example platform_probe
```

Running Hyprland nested is the cheap way to test it:
`ci/hypr-nested.sh` starts one inside the current session, lifts the session environment from the
live shell, and leaves the host desktop alone.

## What is still not done

**Window enumeration** (`window_layout`) remains false. `hyprctl -j clients` provides it on Hyprland,
but wiring a window list into the layer is a separate piece of work from reading the compositor's
displays and cursor — it needs a geometry model that the other backends do not currently share. The
data is there; the plumbing is not.

Screenshots on Hyprland go through `grim` (wlr-screencopy), which works but is slower than KWin's
ScreenShot2. Measured elsewhere on this project: ~921 ms for `spectacle`, 22.6 ms for ScreenShot2 at
1920x1080. `grim` on a live Omarchy session has not been benchmarked here.
