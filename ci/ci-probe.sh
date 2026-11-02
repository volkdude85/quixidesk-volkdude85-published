#!/bin/bash
# Runs ON the build box. Prints one line the watchdog can parse.
#
# This exists so the watchdog never has to build a quoted command string: nested quoting through
# `ssh "..."` expanded on the wrong side four separate times, each time silently (a symlink length read
# as a log size, a $HOME pointing at the wrong machine, an empty stat target producing size=0).
# A script that runs locally on the box has no quoting to get wrong.
#
# Output: RESULT SIZE CARGO RUSTC STAGE
#   RESULT = PASS | FAIL | RUNNING | NOLOG
#   SIZE   = real log size in bytes (follows the symlink)
set -u

LOG="$HOME/ci-latest.log"
[ -f "$LOG" ] || { echo "NOLOG 0 0 0 -"; exit 0; }

# -L is essential: ci-latest.log is a symlink, and `stat -c %s` on a symlink reports the LENGTH OF THE
# PATH STRING (28 bytes), which never changes — a stall detector built on that compares a constant.
SIZE=$(stat -Lc %s "$LOG" 2>/dev/null || echo 0)
CARGO=$(pgrep -x cargo 2>/dev/null | wc -l)
RUSTC=$(pgrep -x rustc 2>/dev/null | wc -l)
STAGE=$(grep -oE '[0-9]/5' "$LOG" 2>/dev/null | tail -1)

if grep -q "CI PASS" "$LOG" 2>/dev/null; then RES=PASS
elif grep -q "CI FAIL" "$LOG" 2>/dev/null; then RES=FAIL
else RES=RUNNING; fi

echo "$RES $SIZE $CARGO $RUSTC ${STAGE:--}"
