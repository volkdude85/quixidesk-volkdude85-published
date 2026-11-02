#!/bin/bash
# ci.sh — the gate between code and a package.
#
# What it does, in order, and why in that order:
#
#   1. extract a PRISTINE upstream tarball into a throwaway directory
#   2. apply the published patch chain to it — the exact patches the package ships
#   3. build --locked
#   4. run the test suite
#   5. only then package
#
# Steps 1-2 matter more than they look. Testing the working tree proves the tree compiles; it does not
# prove the PATCHES reproduce that tree. A patch that silently skips a file, or a hunk that applies
# with fuzz into the wrong place, produces a package that differs from the code that was tested. This
# has already happened once (a 279-line file appended four times), so the chain is verified from
# scratch every run.
#
# Any failure aborts before packaging, so a broken build cannot leave a .pkg.tar.zst behind.
#
#   ./ci.sh <package-dir>              full run, ends with a package
#   ./ci.sh <package-dir> --no-package stop after tests
#   ./ci.sh <package-dir> --quick      skip the pristine rebuild, test the working tree only

set -uo pipefail

PKGDIR="${1:-}"
MODE="${2:-}"
[ -n "$PKGDIR" ] || { echo "usage: ci.sh <package-dir> [--no-package|--quick|--chain-only]" >&2; exit 2; }
[ -f "$PKGDIR/PKGBUILD" ] || { echo "no PKGBUILD in $PKGDIR" >&2; exit 2; }
PKGDIR=$(cd "$PKGDIR" && pwd)

FAILED=0
step() { echo; echo "═══ $* ═══"; }
fail() { echo "  ✗ CI FAIL: $*" >&2; FAILED=1; }

export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export CARGO_NET_OFFLINE="${CARGO_NET_OFFLINE:-true}"

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

# ------------------------------------------------------- 0. source checksums
# makepkg verifies source=() against sha256sums and refuses to build on a mismatch, so a chain that
# applies perfectly still cannot ship if the sums are stale. That happened twice: a patch was edited
# and the sums were not, and only the packaging stage caught it. Check first, and say which file.
step "0/5  source checksums"
CHECK_FAILED=0
python3 - "$PKGDIR" <<'PYCHK' || CHECK_FAILED=1
import hashlib, re, sys, pathlib
root = pathlib.Path(sys.argv[1])
text = (root / "PKGBUILD").read_text()
pkgname = re.search(r"^pkgname=(\S+)", text, re.M).group(1)
pkgver = re.search(r"^pkgver=(\S+)", text, re.M).group(1)
src = re.search(r"source=\((.*?)\n\)\n", text, re.S).group(1)
sums = re.search(r"sha256sums=\((.*?)\n\)\n", text, re.S).group(1)
entries = [l.strip().strip('"') for l in src.strip().split("\n")]
wants = [l.strip().strip("'") for l in sums.strip().split("\n")]
if len(entries) != len(wants):
    print(f"  ✗ {len(entries)} source entries but {len(wants)} checksums")
    sys.exit(1)
bad = 0
for e, want in zip(entries, wants):
    name = e.split("::")[0].replace("${pkgname}", pkgname).replace("${pkgver}", pkgver)
    f = root / name
    if not f.exists():
        continue          # makepkg will fetch it; nothing to verify yet
    got = hashlib.sha256(f.read_bytes()).hexdigest()
    if got != want:
        print(f"  ✗ {name}: checksum mismatch")
        print(f"      package {want}")
        print(f"      on disk {got}")
        bad += 1
if bad:
    print(f"  {bad} file(s) do not match sha256sums — refresh the PKGBUILD")
    sys.exit(1)
print("  ✓ every local source matches sha256sums")
PYCHK
[ "$CHECK_FAILED" -eq 0 ] || exit 1

# ------------------------------------------------------------------ 1. pristine
if [ "$MODE" != "--quick" ]; then
    step "1/5  pristine upstream"
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/quixi-ci-XXXXXX") || { fail "no temp dir"; exit 1; }
    TARBALL=$(find "$PKGDIR" -maxdepth 1 -name '*.tar.gz' | head -1)
    if [ -z "$TARBALL" ]; then
        # A fresh clone has no tarball (it is gitignored). Let makepkg fetch and CHECKSUM it,
        # rather than downloading by hand and trusting whatever arrives.
        echo "  no tarball in $PKGDIR — fetching and verifying the sources named in source=()"
        if ( cd "$PKGDIR" && makepkg --verifysource --noconfirm ) >/tmp/ci-verifysource.log 2>&1; then
            TARBALL=$(find "$PKGDIR" -maxdepth 1 -name '*.tar.gz' | head -1)
        else
            fail "could not fetch/verify sources — see /tmp/ci-verifysource.log"
            tail -5 /tmp/ci-verifysource.log | sed 's/^/    /'
        fi
    fi
    [ -n "$TARBALL" ] || { echo "  ✗ CI FAIL: no upstream tarball"; exit 1; }
    if [ -n "$TARBALL" ]; then
        tar xf "$TARBALL" -C "$WORK" || fail "tarball will not extract"
        SRC=$(find "$WORK" -maxdepth 1 -type d -name 'QuixiDesk-*' | head -1)
        echo "  $(basename "${TARBALL}") -> $(basename "${SRC:-none}")"
    fi

    # --------------------------------------------------------------- 2. patches
    step "2/5  patch chain"
    if [ -n "${SRC:-}" ]; then
        cd "$SRC" || fail "cannot enter source"
        APPLIED=0
        # The order comes from prepare(), which is the order makepkg actually applies. source=() is a
        # file list and its order means nothing; sorting it is only a guess at prepare() and the two
        # disagree the moment a series is not authored in numeric order (this one is not).
        PATCH_ORDER=$(sed -n '/^prepare()/,/^}/p' "$PKGDIR/PKGBUILD" \
                      | grep -oE 'patch -Np1 -i "\$\{srcdir\}/[^"]+' \
                      | sed 's|.*/||')
        if [ -z "$PATCH_ORDER" ]; then
            PATCH_ORDER=$(sed -n '/^source=(/,/^)/p' "$PKGDIR/PKGBUILD" | grep -oE '[0-9]{4}-[a-z-]+\.patch' | sort)
        fi
        for p in $PATCH_ORDER; do
            # NOT `-s`: quiet mode hid a hunk that had been applying with fuzz 2 for days. Fuzz
            # means context lines were discarded and the hunk landed somewhere it does not fully
            # describe, which is exactly the "the tree is not what the patch says" failure this
            # gate exists to catch. An offset is fine — the content matched, only the line number
            # moved, which is normal when an earlier patch changes the file's length.
            out=$(patch -p1 -i "$PKGDIR/$p" 2>&1)
            rc=$?
            if [ "$rc" -ne 0 ]; then
                fail "$p did not apply"
                printf '%s\n' "$out" | head -8 | sed 's/^/      /'
            elif printf '%s\n' "$out" | grep -qi 'with fuzz'; then
                fail "$p applied WITH FUZZ — context was ignored, re-cut the hunk"
                printf '%s\n' "$out" | grep -i fuzz | sed 's/^/      /'
            else
                echo "  ✓ $p$(printf '%s\n' "$out" | grep -qi 'offset' && echo " (offset $(printf '%s\n' "$out" | grep -oiE 'offset [-0-9]+ lines?' | head -1 | grep -oE '[-0-9]+'))")"
                APPLIED=$((APPLIED + 1))
            fi
        done
        [ "$APPLIED" -gt 0 ] || fail "no patches were applied"
        # A .rej means part of the chain was rejected: the tree is not what gets built.
        if find . -name '*.rej' 2>/dev/null | grep -q .; then
            fail "reject files produced — chain is broken"
        fi
        echo "  $APPLIED patches applied clean, no rejects"
        TREE="$SRC"
    fi
    if [ "$MODE" = "--chain-only" ]; then
        step "result"
        [ "$FAILED" -eq 0 ] || { echo "  ✗ CI FAILED — the patch chain does not apply" >&2; exit 1; }
        echo "  ✓ chain verified against a pristine tarball"
        exit 0
    fi
else
    step "1-2/5  skipped (--quick: testing the working tree)"
    TREE="$PKGDIR/src/QuixiDesk-$(sed -n 's/^pkgver=\(.*\)/\1/p' "$PKGDIR/PKGBUILD")"
    [ -d "$TREE" ] || { fail "no prepared tree at $TREE"; exit 1; }
fi

cd "$TREE" || { fail "cannot enter $TREE"; exit 1; }

# ------------------------------------------------------------------- 3. build
step "3/5  build"
# A cold cache cannot build offline. Fetch once (network) before the offline build, and say so —
# the laptop failed CI purely because `globset` was not in its registry and --offline was set.
if ! cargo build --release --workspace --locked >/tmp/ci-build.log 2>&1; then
    # Two different error texts mean the same thing: the crate cache/registry is not populated, so
    # --offline cannot resolve. Matching only the first one left Porsche failing with
    # "no matching package named `chrono` found ... offline mode" and no fetch attempted.
    if grep -qE "attempting to make an HTTP request, but --offline|no matching package named|offline mode \(via" /tmp/ci-build.log; then
        echo "  cold cargo cache — fetching (needs network)"
        CARGO_NET_OFFLINE=false cargo fetch --locked >/tmp/ci-fetch.log 2>&1 \
            && echo "  ✓ fetched" || echo "  fetch failed — see /tmp/ci-fetch.log"
    fi
fi
if cargo build --release --workspace --locked >/tmp/ci-build.log 2>&1; then
    echo "  ✓ built"
else
    fail "build failed — see /tmp/ci-build.log"
    tail -15 /tmp/ci-build.log | sed 's/^/    /'
fi

# -------------------------------------------------------------------- 4. test
step "4/5  tests"
# The unit tests plus the suites that are safe to run unattended. input_synthesis, bug_hunt and stress
# inject real keystrokes and pointer events, so they stay manual — running them here would type into
# whatever happens to be focused.
# Every suite runs inside its own Xvfb display, single-threaded.
#
# Two reasons, both learned the hard way:
#   * CI must not inherit the developer's desktop. These suites capture the screen and read displays;
#     run from a bare shell they fail, run from a live session they pass, and either way the result
#     says nothing about the code.
#   * Several of them mutate process-global environment variables (PATH, XDG_CURRENT_DESKTOP,
#     WAYLAND_DISPLAY) to simulate different desktops. Parallel threads share that environment, so
#     they clobber each other — measured 3 passed / 4 failed in parallel versus 7 passed / 0 failed
#     single-threaded.
XVFB=(xvfb-run -a -s "-screen 0 1920x1080x24")

if "${XVFB[@]}" cargo test --release --locked -p quixi-platform --lib >/tmp/ci-test.log 2>&1; then
    echo "  ✓ $(grep -oE '[0-9]+ passed' /tmp/ci-test.log | head -1) (quixi-platform lib)"
else
    fail "unit tests failed"
    grep -E "FAILED|panicked" /tmp/ci-test.log | head -8 | sed 's/^/    /'
fi

for suite in compat compat_desktops capture_modes linux_computer_use launch; do
    if "${XVFB[@]}" cargo test --release --locked -p quixi-platform --test "$suite" -- --test-threads=1 >"/tmp/ci-$suite.log" 2>&1; then
        echo "  ✓ $suite ($(grep -oE '[0-9]+ passed' "/tmp/ci-$suite.log" | head -1))"
    else
        fail "$suite failed"
        grep -E "FAILED|panicked" "/tmp/ci-$suite.log" | head -5 | sed 's/^/    /'
    fi
done

# ---------------------------------------------------------------- 5. package
if [ "$FAILED" -ne 0 ]; then
    step "result"
    echo "  ✗ CI FAILED — no package produced"
    exit 1
fi

step "5/5  package"
if [ "$MODE" = "--no-package" ]; then
    echo "  skipped (--no-package)"
else
    cd "$PKGDIR" || { fail "cannot enter $PKGDIR"; exit 1; }
    if makepkg -f --noconfirm >/tmp/ci-pkg.log 2>&1; then
        ART=$(ls -t "$PKGDIR"/*.pkg.tar.zst 2>/dev/null | grep -v debug | head -1)
        echo "  ✓ $(basename "${ART:-package}") $(stat -c %s "${ART:-/dev/null}" 2>/dev/null) bytes"
    else
        fail "makepkg failed — see /tmp/ci-pkg.log"
        tail -12 /tmp/ci-pkg.log | sed 's/^/    /'
        exit 1
    fi
fi

step "result"
echo "  ✓ CI PASS"
