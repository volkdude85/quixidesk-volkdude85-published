#!/bin/bash
# Launch a nested Hyprland instance inside the running KDE Wayland session, purely so hyprctl has
# something real to talk to while the Linux platform layer is ported to it.
#
# Two rules this respects:
#   * It is a WINDOW on the Samsung (HDMI-A-1), never a session switch and never on the Vizio.
#   * It dies with its window; nothing is left running.
#
# The session env has to be lifted from the live plasmashell because a systemd/ssh context has none of
# it, and Wayland socket numbers renumber across reboots (wayland-0 vs wayland-1).

set -u

PLASMA_PID=$(pgrep -x plasmashell | head -1)
if [ -z "$PLASMA_PID" ]; then
    echo "no plasmashell running — this rig is not in a Plasma Wayland session" >&2
    exit 1
fi

# Lift the live session environment rather than guessing socket names.
for var in WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS XDG_SESSION_TYPE XDG_CURRENT_DESKTOP; do
    val=$(tr '\0' '\n' < "/proc/$PLASMA_PID/environ" 2>/dev/null | grep -m1 "^${var}=" | cut -d= -f2-)
    [ -n "$val" ] && export "$var=$val"
done

echo "session: WAYLAND_DISPLAY=$WAYLAND_DISPLAY DISPLAY=$DISPLAY XDG_SESSION_TYPE=$XDG_SESSION_TYPE"

LOG="$HOME/.local/share/nora-hypr-nested.log"
mkdir -p "$(dirname "$LOG")"

# A throwaway config keeps this from touching any real Hyprland config the user may have later.
CONF=$(mktemp /tmp/nested-hypr-XXXX.conf)
cat > "$CONF" <<'HYPRCONF'
monitor=,preferred,auto,1
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    force_default_wallpaper = 0
    background_color = 0x000000
}
decoration {
    blur { enabled = false }
}
animations {
    enabled = false
}
HYPRCONF

echo "config: $CONF"
echo "log:    $LOG"

# Nested: Hyprland detects it is inside another Wayland compositor and takes aquamarine's Wayland
# backend, opening as a window in the host session.
setsid env HYPRLAND_NO_CRASHREPORTER=1 Hyprland --config "$CONF" >"$LOG" 2>&1 &
NEWPID=$!
echo "pid:    $NEWPID"

# Wait for the instance signature to appear — that is the moment hyprctl becomes usable.
#
# The signature must be EXPORTED, not merely discovered: hyprctl finds its compositor through
# HYPRLAND_INSTANCE_SIGNATURE and nothing else, so a readiness probe that reads the directory but
# does not export the value always fails while the compositor is running perfectly well. That is
# exactly what this script did on its first run — it reported FAILED against a live instance.
for i in $(seq 1 40); do
    DIR=$(ls -dt "$XDG_RUNTIME_DIR"/hypr/*/ 2>/dev/null | head -1)
    if [ -n "$DIR" ]; then
        HYPRLAND_INSTANCE_SIGNATURE=$(basename "${DIR%/}")
        export HYPRLAND_INSTANCE_SIGNATURE
        if hyprctl -j monitors >/dev/null 2>&1; then
            echo "ready after $((i * 250))ms, signature $HYPRLAND_INSTANCE_SIGNATURE"
            break
        fi
    fi
    sleep 0.25
done

if ! hyprctl -j monitors >/dev/null 2>&1; then
    echo "FAILED to come up; last 20 lines of the log:" >&2
    tail -20 "$LOG" >&2
    exit 1
fi

echo
echo "=== hyprctl -j monitors ==="
hyprctl -j monitors | head -c 600
echo
echo "=== hyprctl -j cursorpos ==="
hyprctl -j cursorpos
echo
echo "=== hyprctl -j activeworkspace ==="
hyprctl -j activeworkspace | head -c 300
echo
echo "=== hyprctl -j clients (should be empty on a fresh nested instance) ==="
hyprctl -j clients | head -c 200
