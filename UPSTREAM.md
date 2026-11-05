# What to offer upstream, and what to keep home

The fork objection is the only one left standing, and it is fair: a store listing belongs to the project
that maintains the app. This file exists so the ask on Eric is small, reviewable, and obviously a gift
rather than a favour.

**The number that decides it:** the series is 115 patches and 32,386 lines. Almost none of that belongs in
Eric's tree. What belongs there is the Linux platform work, which is **one patch and six follow-ups —
about 7,970 lines, 87% of it a single coherent change.**

| What | Lines | Belongs upstream? |
|---|---:|---|
| `0001-linux-support` — makes the app build and run on Linux at all | 6,944 | **yes** — the whole ask |
| `0005-headless` — run without a display, for CI and servers | 309 | yes |
| `0104-a-missing-package-comes-with-its-command` — tell the user what to install | 369 | yes |
| `0011-test-portability` | 138 | yes |
| `0035-no-mac-tooling` | 97 | yes |
| `0016-test-portability-containers` | 62 | yes |
| `0100-handheld-windows-open-maximized` | 29 | yes |
| `0099-window-fits-the-screen` | 25 | yes |

## The ask, stated so it is easy to accept

One Pull Request: **`0001-linux-support`**. One sentence to Eric: *"QuixiDesk has never built on Linux;
this makes it build, run, and reach a window. It is MIT, it is yours, take it or leave it."*

Everything else in the table is a follow-up after he has taken the first one, and each is small enough to
be read in a sitting. Nothing in that list has to do with the edition — no persona, no colours, no
skills, no branding, no name of mine on any of it.

What that means for him is not "accept my fork." It is "here is a platform you don't have, and it costs
you nothing to say no."

## What stays home, and why

**Edition work** — the persona file, the colours, the retro theme, `its-your-edition`, the tool pages'
layout, the skills library. This is the product difference, and upstream has no reason to want it.

**Anything with a person in it** — `0024-his-colours-and-his-words`, the shipped persona, the credits
page's first-person voice. These exist for one installation and should never be offered anywhere.

**Household material** — none of it is in the published tree any more (see the sanitizer in `prepare()`),
and the guard exists so it cannot come back.

## The order this should happen in

1. Eric takes `0001-linux-support` (or says no, which is also an answer and costs nothing to hear).
2. The follow-ups go in one at a time, so a rejection of one is not a rejection of the whole.
3. Only then does `org.quixidesk.QuixiDesk` become submittable — by him, with the source-building
   manifest already in this repository (`flatpak/io.github.volkdude85.quixidesk.sourcebuild.yml`).
4. The edition stays on its own signed hub, which is where it belongs and where it already works.

Step 3 is the only one that has to involve Flathub at all, and it stops being a favour asked of a
volunteer maintainer the moment upstream ships a Linux build of its own.

---

*Written 2026-11-05, the day the Flathub submission was withdrawn. The line counts above are measured
from the patch files, not estimated.*
