# CI

Reproducible build + test for this package, and the tooling that watches it across machines.

| file | what it does |
|---|---|
| `ci.sh` | five stages — extract a pristine upstream tarball, apply every patch, build, test, package |
| `ci-probe.sh` | runs **on** a build box, prints `RES SIZE CARGO RUSTC STAGE` for the watcher |
| `watch-jobs.sh` | polls boxes every 90 s and records whether a build is **moving** |
| `pick-auto.py` | drives a portal file/folder picker with no human and asserts the response code |

## Usage

```sh
./ci.sh <package-dir>              # full run
./ci.sh <package-dir> --no-package # stop after tests
./ci.sh <package-dir> --quick      # skip the pristine rebuild
```

Every test suite runs inside its own `xvfb-run` display, single-threaded. Two reasons: the suites
capture the screen and read displays, so CI must not inherit a developer's desktop; and several
mutate process-global environment variables to simulate other desktops, so parallel threads clobber
each other (measured 3 passed / 4 failed in parallel versus 7 / 0 single-threaded).

`input_synthesis`, `bug_hunt` and `stress` inject real keystrokes and pointer events, so they stay
manual — running them here would type into whatever happens to be focused.

## Watching long builds

`watch-jobs.sh` records one line per check. The test is **motion** — log growth plus live
`cargo`/`rustc` — because a dead build and a slow build look identical if the only check is that a
process exists. No growth and no compiler for 420 s is reported as `STALLED`.

## Verifying a picker without a human

The portal answers on a request path you can compute *before* calling, so the `Response` signal can be
subscribed first and never missed. A synthetic Escape dismisses the dialog.

- `0` — a selection came back
- `1` — cancelled
- `2` — opened and dismissed some other way
- `null` — **no dialog ever existed** (a headless box cannot host one; this is not a product defect)
