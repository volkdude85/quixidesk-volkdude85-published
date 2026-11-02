## What this changes

<!-- One or two sentences. If it fixes a bug, the bug's symptom in the same words a user would use. -->

## Which patch

<!--
Patches are numbered and independent. Name the one you changed (0001-linux-support, 0004-skills,
…) or say "new patch" and where it sits in the order.
-->

## Checks

- [ ] `ci/ci.sh . --chain-only` passes from a pristine tarball — no rejects, **no fuzz**
- [ ] `ci/ci.sh .` builds, tests and packages
- [ ] If a hot path changed, the number in the docs was re-measured, not adjusted by hand
- [ ] If a capability was added or removed, `capabilities()` and `optdepends` agree with it

## If this changes a patch

Patches must be regenerated against a pristine checkout of the upstream tag, not hand-edited:

```sh
tar xf quixidesk-<pkgver>.tar.gz          # pristine upstream
cd QuixiDesk-<pkgver>
for p in <patches up to and including yours>; do patch -Np1 -i "$p"; done   # apply the chain
# ... make the change ...
diff -Naur <pristine-without-your-patch> <pristine-with-your-patch> > 00NN-name.patch
```

Then refresh `sha256sums` in the PKGBUILD. A patch that applies with fuzz is a patch that will
break on the next upstream release, and CI fails on it deliberately.

## Anything the reviewer should know is unfinished

<!-- Say it here rather than letting it be discovered later. -->
