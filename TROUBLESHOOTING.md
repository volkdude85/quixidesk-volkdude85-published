# When it will not build, or builds and misbehaves

Every entry here is a failure that actually happened on this tree, what it looked like from the outside,
and the thing that was actually wrong. The point is that the next person recognises the symptom instead
of re-deriving the cause.

## "lock file version `4` was found, but this version of Cargo does not understand this lock file"

**What it looks like:** the build dies before compiling anything. Reads like a corrupt `Cargo.lock`.

**What it is:** a cargo older than 1.78. Debian 12 and Ubuntu 22.04 ship older ones. `Cargo.lock` here is
format v4.

**Fix:** rustup, or backports.

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
. "$HOME/.cargo/env"
```

`packaging/debian/build-deb.sh` checks the version up front and prints this instead of letting cargo
say it.

## A patch fails, and the tree is fine

**What it looks like:** `Hunk #1 FAILED` on something like `0053-journal.patch`, or
`Reversed (or previously applied) patch detected!` on the first patch in the series.

**Two causes, both common:**

1. **Wrong order.** `source=()` in the PKGBUILD is grouped by area and does not list patches in the order
   `prepare()` applies them — its first entry is `0053-journal.patch` while `prepare()` starts at `0001`.
   Anything that applies the series must take the order from `prepare()`:

   ```sh
   sed -n '/^prepare()/,/^}/p' PKGBUILD \
     | grep -oE '\$\{srcdir\}/[0-9]{4}-[A-Za-z0-9.-]+\.patch' | sed 's|.*/||' | awk '!seen[$0]++'
   ```

2. **Patching an already-patched tree.** `work/`, `src/` and `pkg/` are scratch. Re-running a build
   script without clearing them applies the series on top of itself and everything after the first
   conflict fails. `makepkg -C` and `rm -rf src pkg` are the answer.

## "missing target/release/quixi-chrome-native-host"

**What it looks like:** cargo reports a clean build, then the packaging step cannot find one of the eight
binaries.

**What it is:** the workspace has eight binaries spread across several crates. Building two of them
(`-p quixi-app -p quixi-engine`) produces `QuixiDesk` and `quixi` and nothing else.

**Fix:** what `build()` does — `cargo build --release --workspace --locked --lib` and then `--bins`.

## A skill file that keeps growing

**What it looks like:** `SKILL.md` is 7009 bytes on the first build and 21027 on the second. Nothing
errors. The page shows the same card.

**What it is:** a patch that CREATES a file must mark it `--- /dev/null` in its header. If it says
`--- a/path` instead, `patch` still creates the file — but `prepare()`'s cleanup computes what to delete
from the `--- /dev/null` markers, so it never learns about that file and the next build appends the same
content again.

**Fix:** regenerate the patch from a real diff against a tree that lacks the file; check with
`grep -c -- '--- /dev/null' <patch>` and make sure it matches the number of files being added.

## The tools page freezes the moment you type in the search box

**What it looks like:** one character typed, then the window spins. Any automation call to the page times
out with `action_timeout` while the renderer keeps burning CPU.

**What it is:** the filter sets `status.textContent` on every pass, and a `MutationObserver` on the
document calls the filter on every change. The filter's own write re-fires the observer forever.

**Fix:** every write in an observer's callback has to be conditional — assign only when the value
differs. Fixed in patch `0105`.

## The Hermes panel says "0 of 0" with 288 skills on disk

**What it looks like:** the library is mounted, the directory is full of `SKILL.md`, the panel is empty.

**What it is:** the engine does not read `QUIXI_HERMES_HOME`. `skill_roots()` is `$HOME/.hermes/profiles/*/skills`,
plus `QUIXI_SKILL_ROOTS`, plus the bundled directory — a mount nobody points at is decoration.

**Fix:** set `QUIXI_SKILL_ROOTS` to the mounted library (`/host-hermes/skills/default` for the scrubbed
export, `/host-hermes/profiles/<name>/skills` for a live profile). Setting it REPLACES auto-discovery,
so it must list everything that should be found outside the bundled set.

## One long list instead of three panels

**What it looks like:** the page renders every skill under the first panel and the other two are empty.

**What it is:** the panels group on the `owner` field of each skill, and `list_local_skills` builds those
objects itself. If it does not copy `owner` out of the manifest, every skill falls through the page's
catch-all into panel one.

**Fix:** the engine passes `owner` through; a skill found by walking the bundled directory with no
manifest entry reports `quixidesk`. Patch `0103` in this series.

## Skills the build never wrote are filed under the build's own panel

**What it looks like:** the "QuixiDesk tools & skills" panel reads 29 of 29 when the package ships 8.

**What it is:** the panel used to decide provenance from the shape of the id — a slash meant "came from a
Hermes root". A Hermes library can hold a skill at the TOP of a root with no area folder above it, and
those have no slash either. 21 of them were shown as if this edition had written them.

**Fix:** group on the engine's `owner`, which comes from the root that was walked (`quixidesk` for the
bundled directory, `user` for the data directory, `hermes` for everything mounted). The id is a name; the
owner is a fact.

## `makepkg` says a source file failed the validity check

**What it looks like:** every patch passes, and the tarball — the source the whole build starts from —
fails.

**What it is:** regenerating `sha256sums` from `source=()` hashes the files on disk, and the tarball
entry is a URL (`${pkgname}-${pkgver}.tar.gz::https://…`). Hash the URL string and you get a hole where a
checksum belongs.

**Fix:** expand `${pkgname}`/`${pkgver}`, take the part before `::`, and hash the local file. Then
`makepkg --verifysource` should report every entry `Passed` — all of them, not most.

## The container window appears and then vanishes after ~10 seconds

**What it looks like:** `docker ps` shows it up, then `Exited (0)`, and the app log ends with
`native event loop stopped` and no error above it.

**What it is:** the window was closed. On this stack that has meant the UI failed to come up and the
event loop had nothing left to run — worth checking the resource file the image was built with before
blaming the container runtime. Compare it against a known-good build by mounting one file over:

```sh
docker run … -v /path/to/good/capability-workflows.js:/usr/lib/quixidesk/resources/ui/capability-workflows.js:ro …
```

If the mounted version stays up, the difference is in your change, not in the image.
