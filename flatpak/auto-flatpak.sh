#!/bin/bash
# Keep the installed Flatpak equal to the newest published package — automatically.
#
#   ./flatpak/auto-flatpak.sh            one pass: build if the package changed, then exit
#   ./flatpak/auto-flatpak.sh --watch    stay resident and do that every few seconds (what systemd runs)
#
# Run as quixidesk-flatpak.service (Type=simple, Restart=always).
#
# WHY A LOOP AND NOT A SYSTEMD PATH UNIT. The path unit was the obvious answer and it does not work
# here: with PathExistsGlob — and with PathChanged on the directory as well — systemd re-fired the
# oneshot every time it exited, because the condition was still true when the service finished.
# Measured: a run every six seconds, ~14,000 a day. The stamp below turned those runs into no-ops
# instead of rebuilds, which is a guard, not a fix.
#
# A five-second poll is edge-triggered by construction: the package's name, size and mtime are the
# identity, and an unchanged identity is silence. It is also the pattern already proven on this box.
set -uo pipefail
REPO="${QUIXIDESK_REPO:-$HOME/Projects/quixidesk-published}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG="$STATE/quixidesk-flatpak.log"
STAMP="$STATE/quixidesk-flatpak.last"
mkdir -p "$STATE"

say() { printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG"; }

newest_pkg() { ls -t "$REPO"/quixidesk*-[0-9]*-x86_64.pkg.tar.zst 2>/dev/null | grep -v debug | head -1; }

# makepkg writes the .pkg.tar.zst in place, so "the file exists" is not "the file is complete": wait for
# makepkg to exit, then for the size to stop changing.
settle() {
  local pkg=$1 last="" stable=0 size
  for _ in $(seq 1 360); do pgrep -x makepkg >/dev/null || break; sleep 5; done
  for _ in $(seq 1 60); do
    size=$(stat -c %s "$pkg" 2>/dev/null) || return 1
    if [ "$size" = "$last" ]; then
      stable=$((stable + 1))
      [ "$stable" -ge 2 ] && return 0
    else
      stable=0
    fi
    last="$size"
    sleep 3
  done
  return 1
}

check_and_build() {
  local pkg sig rc
  pkg=$(newest_pkg) || true
  [ -n "${pkg:-}" ] || return 0
  sig=$(stat -c '%n %s %Y' "$pkg" 2>/dev/null) || return 0
  if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$sig" ]; then
    return 0
  fi
  say "package changed: $(basename "$pkg")"
  settle "$pkg" || { say "settle gave up on $pkg"; return 1; }
  ( cd "$REPO" && ./publish-local.sh --flatpak ) 2>&1 | tee -a "$LOG" | tail -12
  rc=${PIPESTATUS[0]:-1}
  if [ "$rc" -eq 0 ]; then
    printf '%s\n' "$sig" > "$STAMP"
    say "done — the installed Flatpak is the published package again"
  else
    say "FAILED — see $LOG"
    return 1
  fi
}

if [ "${1:-}" = "--watch" ]; then
  say "watching $REPO"
  # Backoff, because a failure must not become a loop. A broken package leaves the stamp unwritten, so
  # the watcher sees it as new again on the very next tick — and each attempt spends six seconds settling
  # before it can fail. Left alone that is an attempted build every ten seconds for as long as nobody
  # looks, which is worse than a loud failure: it is a quiet one. Start at a minute and double to fifteen.
  wait_s=5
  while :; do
    if check_and_build; then
      wait_s=5
    else
      wait_s=$(( wait_s < 60 ? 60 : wait_s * 2 ))
      [ "$wait_s" -gt 900 ] && wait_s=900
      say "retrying in ${wait_s}s — the package on disk is unchanged and still failing"
    fi
    sleep "$wait_s"
  done
fi

check_and_build || exit 1
