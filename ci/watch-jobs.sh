#!/bin/bash
# Watches long builds on the other boxes and records whether they are MOVING.
#
# A dead build and a slow build look identical if the only check is "does a process exist". The test
# here is motion: log growth plus live cargo/rustc processes. A job that stops moving for STALL_SECS is
# reported as STALLED rather than left to hang.
#
# All the remote logic lives in ci-probe.sh, which runs ON each box. Earlier versions built a quoted
# command string per check, and nested quoting through `ssh "..."` expanded on the wrong side four
# separate times — every time silently, which is the worst way for a monitor to fail:
#   * `stat -c %s` on the ci-latest.log symlink reported the LENGTH OF THE PATH (28 bytes), so "log
#     growth" compared a constant and could never fire
#   * `$(...)` inside the double-quoted ssh string expanded on the LOCAL side with an empty $f, giving
#     size=0 every check
#   * `$HOME` expanded locally, so the remote searched this machine's home for the other box's log
#   * `~` inside a variable stayed literal, so the glob never expanded and every check said NOLOG
# A script that runs on the box has no quoting to get wrong.
STATE="$HOME/Projects/quixidesk-ci/jobs-state.log"
# Set these to your own build hosts, e.g. user@host or a name from ~/.ssh/config.
: "${LAPTOP_HOST:=laptop}"
: "${PORSCHE_HOST:=porsche}"

STALL_SECS=420
INTERVAL=90

while true; do
    for spec in "laptop|$LAPTOP_HOST" \
                "porsche|$PORSCHE_HOST"; do
        name="${spec%%|*}"
        host="${spec#*|}"
        prev="$HOME/Projects/quixidesk-ci/.prev-$name"

        out=$(timeout 30 ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" '~/ci-probe.sh' 2>/dev/null)
        [ -n "$out" ] || out="UNREACHABLE 0 0 0 -"
        read -r res size cargo rustc stage <<< "$out"
        size=${size:-0}; cargo=${cargo:-0}; rustc=${rustc:-0}

        read -r last_move prev_size < "$prev" 2>/dev/null || { last_move=0; prev_size=0; }
        now=$(date +%s)

        # Baseline first: with no history, "no growth since 0" reads as an infinite stall, which is not
        # a measurement of anything.
        if [ "${last_move:-0}" -eq 0 ] 2>/dev/null; then
            echo "$now $size" > "$prev"
            echo "$(date +%H:%M:%S)  $name  baseline size=$size res=$res" >> "$STATE"
            continue
        fi

        if [ "$res" = "UNREACHABLE" ]; then
            verdict="BOX-UNREACHABLE"
        elif [ "$res" = "PASS" ] || [ "$res" = "FAIL" ]; then
            verdict="$res"
        elif [ "$size" -gt "${prev_size:-0}" ] 2>/dev/null; then
            verdict="WORKING"
            echo "$now $size" > "$prev"
        elif [ "$cargo" -gt 0 ] 2>/dev/null || [ "$rustc" -gt 0 ] 2>/dev/null; then
            # Release builds can sit silent for minutes while linking — trust the compiler, not the log.
            verdict="WORKING(compile)"
        else
            still=$(( now - ${last_move:-0} ))
            if [ "$still" -gt "$STALL_SECS" ]; then
                verdict="STALLED(${still}s no growth)"
            else
                verdict="idle${still}s"
            fi
        fi

        echo "$(date +%H:%M:%S)  $name  res=$res stage=[$stage] size=$size cargo=$cargo rustc=$rustc => $verdict" >> "$STATE"

        # Keep the file bounded without losing the recent picture.
        lines=$(wc -l < "$STATE" 2>/dev/null || echo 0)
        if [ "${lines:-0}" -gt 400 ]; then
            tail -200 "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
        fi
    done
    sleep "$INTERVAL"
done
