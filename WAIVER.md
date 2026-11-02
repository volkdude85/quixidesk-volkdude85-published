# WAIVER — this runs wide open on purpose

**Read this before you install either edition.**

Upstream QuixiDesk ships with limits. This packaging raises most of them and removes a few outright.
That is not an accident, a bug, or something I forgot to finish. It is the point of the build: the
agent is supposed to be able to do the work, and every limit that stops it doing the work got moved
out of the way.

Which means: **if you point this at something you care about, understand what you are handing it.**

Nobody is coming after you for running it. Equally, nobody is coming to save you. This is MIT
software with no warranty, written by one person and an AI, and if it wrecks your machine that is a
thing that happened rather than a thing you can sue over. What you *can* do is read the list below and
decide where your own guardrails belong.

---

## What is wide open, and what it actually means

### Synthetic input — the biggest one

The Linux platform layer can **move the pointer, click anywhere, type into whatever window has focus,
and read the screen**. That is the entire feature. There is no sandbox around it, no confirmation
dialog, and no allowlist of applications.

What that means: an agent running this can act as you at the keyboard and mouse. It can send messages,
click through dialogs, type commands into a terminal, and look at whatever is on screen — including
other people's windows if you share a desktop.

**Build around it:** run it on a dedicated desktop or a VM, not on the session where you do your
banking. Keep it off shared machines. On Wayland the compositor will not stop a program that has
`/dev/uinput` access, so "it's Wayland, it's fine" is not a protection.

### Shell commands hold for 24 hours

`3600 s → 86400 s`. A command that hangs is not killed after an hour; it is killed after a day.

**Build around it:** wrap long-running work in your own timeout. Do not give this a shell on a box
where a stuck process can hold a lock, a port, or a database transaction for a day.

### The agent loop does not stop

| limit | upstream | here |
|---|---|---|
| rounds | 100 | **1000** |
| subagents | 4 | **32** |
| child rounds | 12 | **200** |
| subagent history | 2 MiB | 64 MiB |

A thousand rounds at 32 subagents is not a chat session, it is a small cluster you did not ask for. If
your model endpoint bills per token, this is where the bill comes from.

**Build around it:** set a spend cap at the provider, not in the app. Cap concurrency at your API tier.

### Attachments and memory sizes

`8 → 64 files`, `5 → 64 MiB` per image, `1 → 64 MiB` text, `20 → 512 MiB` total. MCP frames and SSE
streams go from 16 MiB to **256 MiB** each.

That is 512 MiB of anything, per request, handed to a model — which, if that model is remote, is
512 MiB uploaded to someone else's server.

### Credentials are on disk in plain-ish form

There is **no keyring by default.** Keys live in `~/.quixi/` encrypted with a 32-byte key file that
sits next to them, mode `0600`. AES-256-GCM, real crypto — protecting you from a stray backup, not
from anyone who can read your home directory.

`QUIXI_USE_KEYRING=1` switches to the OS keyring if you have one you actually trust.

**Build around it:** if this machine holds credentials worth money, either use the keyring or accept
that filesystem permissions are your entire control. On a shared or multi-user box, do not do this.

### Your memory goes on disk in the clear (volkdude85 edition only)

The MemPalace-shaped memory writes markdown files, unencrypted, readable by anything running as you.
Whatever the agent decides is worth remembering gets written down and stays written down.

**Build around it:** point the memory root at a path you are willing to expose, and back it up or
delete it deliberately. Do not let it ingest anything you would not want found later.

### The microphone (both editions, if voice is on)

Local Whisper transcribes whatever the mic hears. It is local, which is the good part. It is still an
always-available microphone.

### If you point it at a cloud model

Everything above becomes an outbound transfer: screen captures, file contents, memory, transcripts. The
local-model path keeps it on your machine; a cloud endpoint does not. That is a provider decision, not
a setting in this package, and it is the single biggest switch here.

---

## What I am not claiming

- **Not audited.** One person plus an AI, over a few weeks. It is tested — three machines, 57 tests,
  46 cross-desktop checks — and testing is not the same as an audit.
- **Not hardened.** Where a choice existed between "restrictive" and "it works", it usually went to
  "it works".
- **Not supported.** MIT, no warranty, no SLA. Issues and pull requests are welcome; obligations are
  not implied.
- **Not a security boundary.** Do not run it as root to get it working. Do not give it a shell on a
  machine that matters more than the task does.

## What I would actually do

1. Dedicated VM or dedicated desktop session, nothing else on it.
2. Local model unless you have a specific reason for cloud.
3. Provider-side spend caps before you ever run a thousand-round loop.
4. Keyring on, or nothing valuable in `~/.quixi/`.
5. Your own timeout around anything that shells out.
6. Snapshot the disk before the first run. That costs nothing and has saved me twice.
