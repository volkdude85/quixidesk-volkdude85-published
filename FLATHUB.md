# Flathub — submitted, rejected, and why

**Short version:** this edition is not on Flathub, and it was turned down on request rather than never
tried. The rejection is correct on Flathub's own rules, two of the three reasons are fixable, and one of
them is not mine to fix. Nothing about the Flatpak's quality turned on it — the same artifact still
builds, signs, installs and updates from this repository's own hub.

Submitted as [flathub/flathub#10998](https://github.com/flathub/flathub/pull/10998). Closed by a Flathub
maintainer with:

> Ignoring the fact it's LLM-generated submission, Linux support should be contributed upstream instead of
> forking it, then the original app submitted. As it stands, it's not eligible for publishing to Flathub.

That is three separate objections. Taking them in the order they matter:

---

## 1. It packaged a prebuilt binary

The manifest used `buildsystem: simple` and an archive source pointing at
`QuixiDesk/releases/download/v3.6556.12-linux/quixidesk-linux-3.6556.12.tar.gz` — a compiled tarball.

Flathub's builders compile everything from source, always. The reason is not suspicion of any particular
submitter: if the store distributes a binary they did not build, they cannot reproduce it, cannot patch
it, and cannot answer for it. A prebuilt archive fails that requirement on inspection, before anyone
reads the rest of the submission.

**This one is mine and it is fixable.** The Rust toolchain is available to Flathub builds through
`org.freedesktop.Sdk.Extension.rust-stable`; thousands of GNOME-adjacent apps build exactly this way. The
manifest has to say `cargo build --release`, not "here is a tarball".

## 2. It is a fork of an application that is still maintained upstream

QuixiDesk is Eric Hartford's (QuixiAI, MIT). This repository is a patch series — `0001` through `0116` —
laid on top of upstream `v3.6556.12`. Flathub's expectation is that the upstream project owns the store
listing, so there is one maintainer accountable for what ships and updates reach users from the source
that can act on them. A downstream fork in the store splits that.

The maintainer's suggested fix — contribute Linux support upstream, then submit the original app — is the
standard answer and it is the right one.

What that answer runs into: **the Linux support is in this tree, not in upstream's.** `0001-linux-support`
is the first patch. The window, the WebKit backend, the packaging, the skill loader, the small-screen
clamp — that is the work that makes the app installable on Linux at all. "Contribute it upstream" is not
a brush-off here; it is the actual unlock, and it needs Eric to accept it.

## 3. "LLM-generated submission"

A heuristic on the submission itself, and the maintainer said he was setting it aside. It is worth
recording anyway, because it is the objection most likely to sink a future attempt quietly: the
submission text and manifest read as machine-written, and that costs a submission its first impression
regardless of what the code does.

The only fix is the one already being applied everywhere else in this repository — say less, claim less,
and put a number next to every assertion.

---

## What would actually get it accepted, in order

1. **A source-building manifest.** `cargo build --release` under the Rust SDK extension, no archive of a
   prebuilt binary. Mine to do; roughly a day; testable without Flathub's involvement.
2. **The Linux platform work upstreamed.** Not the edition — the platform patches. Eric takes them or he
   does not, but until he does, there is no upstream app to submit that runs on Linux.
3. **Then submit `org.quixidesk.QuixiDesk`, from upstream, with the namespace the app actually owns.**

Until all three are true, resubmitting produces the same answer with less goodwill.

---

## What is lost by not being on Flathub

**Discovery.** A stranger searching a Deck or a desktop for "QuixiDesk" finds nothing in Discover. That is
the whole of it.

## What is not lost

Everything technical. This repository publishes a signed OSTree repository, the identical format Flathub
serves, with the identical `flatpak install` path:

```sh
flatpak remote-add --user --if-not-exists quixidesk --from \
  https://volkdude85.github.io/quixidesk-volkdude85-published/io.github.volkdude85.quixidesk.flatpakref
flatpak install --user -y quixidesk io.github.volkdude85.quixidesk
```

It updates, it verifies against a published key, and it is rebuilt from this repository automatically.
The difference between it and a Flathub listing is who curated it, not whether it works.

---

*Recorded 2026-11-05. If Flathub ever lists this, delete this file and say so in `CHANGELOG.md` — a
document that explains why something is impossible should not outlive the reason.*
