# The tools & skills panel

Two libraries on one page, and a rule about what the page is allowed to show.

## The two libraries

| panel | what it is |
|---|---|
| **QuixiDesk tools & skills** | what the build itself ships: the office-document skills, plus any bundled skill the manifest names |
| **Hermes** | the agent's own procedural library, discovered from the Hermes profiles on the machine, grouped by area |

They are separate on purpose. Mixing them made the small shipped set look like the whole
library and buried the larger one underneath it.

Skills are placed by the `owner` field in `resources/bundled-skills/manifest.json`. A skill with
no owner belongs to the build; one found under a Hermes root belongs to the agent.

**The page places anything it does not recognise in the first panel rather than dropping it.** An
owner value with no matching panel is a filter that silently eats the skill — the app lists six
tools, one is missing, and nothing anywhere says so. That failure happened once here and the
catch-all is why it cannot happen again.

## What the page is allowed to show

The Hermes library is written in the first person about whoever owns the machine — names, family,
a case, a workplace. A published build must not put any of that on screen, and one shipped before
this did.

Nothing is rewritten on disk. The redaction applies to what is **rendered**:

- the card title and description,
- the text the search box matches against,
- **the instructions themselves** — the "Read instructions" reader used to open the whole file
  unredacted, which made every other measure pointless.

The owner keeps their handle, because the handle is on the tin and a generic replacement made every
sentence read like a form letter. Everyone else keeps their role and loses their name.

One name is deliberately absent from the map: it is a first name *and* a parameter that appears in
working instructions, and mapping it turned `Max: 250` into `someone: 250` and `Max width: 60` into
`someone width: 60`. A redaction that corrupts the instructions it is protecting is a bug, not a
safety margin.

## Problems this work ran into

1. **A skill with a new owner value disappeared from the page.** The grouping is a set of filters;
   a value with no bucket matched nothing. Fixed by placing unknown owners in the first panel.
2. **The launcher reported success on an invisible window.** It checked the window's *size* and
   never its map state, so a 1280x840 window that was never mapped counted as "up" while the app
   ran and served its API with nothing on screen. Both conditions are checked now.
3. **The patch chain rejected a patch that was listed twice.** A duplicated `patch -Np1` line in
   `prepare()` made the second application report "previously applied" and produce a `.rej`. The
   chain check in `ci/ci.sh` caught it before it reached a package — that is what the gate is for.
4. **Repeated builds failed with "already exists! Skipping patch."** The list of files the patches
   *create* is hand-maintained and had gone stale, so a second build silently kept an old copy. It
   is now computed from the patch series itself.

## Verifying it

```
./ci/ci.sh . --chain-only     # 101 patches, zero rejects, against a pristine tarball
```

Then build the package, rebuild the image, and count the cards on the page. A number in a source
file is not evidence; the card count is.

Screenshots of the panel are kept **out of this repository on purpose**: the app window carries the
session list down the left side, and a screenshot of it is a picture of somebody's work. They are
kept locally instead.
