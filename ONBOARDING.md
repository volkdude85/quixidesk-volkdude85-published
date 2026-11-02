# First run — what the Volkdude Edition says before it does anything

This is the copy and the decisions for the first launch of `quixidesk-volkdude85`. It exists because
a fresh install arrives with none of the context that makes this edition worth having: no persona
file, no memory, no idea what it is for. Every one of those is a choice the user should make with the
cost in front of them, not a default they discover later.

---

## 1. The first thing on screen

> **This is the Volkdude Edition.**
>
> It ships with a persona called **Nora** — that is who you will be talking to. She is not a
> requirement. She is your first friend on here, the way Tom was everybody's first friend on MySpace:
> present so the place is not empty, and replaceable the moment you want somebody else.
>
> The persona is a file on your disk — `persona.md`. Edit it, replace it, or delete it and write your
> own. Nothing else in the app depends on her.

Why it leads with that: the persona is the most opinionated thing this edition installs, and a user
who is handed a voice without being told it is a file will treat it as the product rather than as a
setting. Naming it first turns a surprise into a choice.

---

## 2. What a memory palace actually is

Plain version, no mysticism:

> Memory is a directory of markdown files. That is the whole design — no database to corrupt, no
> format to migrate, nothing you cannot read with `cat`.
>
> It is laid out the way a palace is described in the old mnemonic technique, because the shape is
> what makes it searchable:
>
> ```
> ~/.mempalace/
>   wings/<project>/rooms/<topic>/drawers/*.md    the long-term store, one file per thing learned
>   journal/                                      one file per conversation, appended as it happens
>   beliefs.db                                    what the agent currently holds to be true
> ```
>
> A wing is a project or a part of your life. A room is a subject inside it. A drawer is one thing
> worth remembering, written as text you could read yourself.

Nothing here is encrypted by default, and nothing is uploaded. It is files on your machine under
your own permissions.

---

## 3. Encryption — pick one, or pick none

The palace is plain text. If the machine is stolen or someone else has an account on it, plain text
means they can read it. Three honest options:

| option | what it protects | what it costs |
|---|---|---|
| **Full-disk encryption** (LUKS at install) | everything, automatically, including the palace | nothing day to day; the disk is unreadable when powered off |
| **A passphrase-wrapped archive** — `age` or GPG over the palace directory, written on a schedule | the backup copies, and the palace at rest if you archive and delete | you must remember the passphrase; losing it loses the memory |
| **Nothing** | — | anyone with the disk reads everything |

The recommendation is **full-disk encryption plus an `age`-encrypted copy of the palace wherever it
gets backed up**. Do not invent a wallet for this and do not let the app hold a key it can also read:
a key the agent can use is a key an attacker who reaches the agent can use. If you already trust a
password manager or a hardware token for secrets, use that and skip the rest.

---

## 4. How memory is allowed to be kept — the actual choice

This is the decision that matters, because it is the one that is expensive to reverse.

### Option A — a sealed archive (recommended)

> One directory you can write to and read from, and cannot delete from. Files accumulate and stay.
>
> **How:** the palace directory is created, then marked append-only at the filesystem level
> (`chattr +a`), so a `rm`, a truncate, or an editor's atomic save all fail. The agent can add a
> drawer and read it back; nothing on the machine can take one away. Unsealing is one command, done
> by you, deliberately.
>
> **Measured, and it changes the shape of this option:** `chattr +a` needs `CAP_LINUX_IMMUTABLE`,
> which an unprivileged process does not have. Running it as an ordinary user on btrfs returns
> `chattr: Operation not permitted` — and then the file is not protected at all, so a design that
> assumes the app can seal itself is a design that silently does nothing. The seal therefore has to
> be applied **once, with elevation, during setup** — a single `pkexec`/`sudo` step the installer
> performs. That is not a limitation to work around, it is the point: the app never holds the
> privilege that would let it unseal, so "the agent cannot delete its own history" is enforced by the
> kernel rather than by the agent's good behaviour.
>
> **What it costs:** it grows forever. At about **782 bytes per exchange**, a conversation-heavy year
> of three sessions a day is roughly **1.6 GiB**. That is the honest number for conversation alone —
> and it is not the ceiling. Anything you attach, index, or let the agent summarise lands in there
> too. For scale: the palace on the machine this edition was built on is **53 GB across 92,428
> files**, and almost all of that is attachments rather than conversation.
>
> **What it buys:** the record is the record. An agent that cannot delete its own history cannot
> quietly rewrite what happened, and neither can you at 3am. When something breaks and you need to
> know what was said last week, it is still there.

### Option B — a live workspace

> The same layout, in a normal directory. Anything can be pruned, edited or deleted.
>
> **What it costs:** pruning is a decision you make every time, and an agent with file tools can make
> it too. Memory is only as trustworthy as the last thing that did not get deleted.
>
> **What it buys:** it stays small, it stays tidy, and correcting a bad memory is a text edit instead
> of a ritual.

### Option C — no persistence

> Nothing is written. Every session starts empty.
>
> **What it costs:** nothing carries over. The agent forgets you between runs, which is the one thing
> a desktop agent is for.
>
> **What it buys:** nothing to leak, nothing to grow, nothing to maintain.

**The recommendation is A**, with the size warning stated in the same breath. Sovereignty means the
options are real — each one says what it leads to, and the app does not pre-select the one it likes.
The default offered is A; choosing B or C is one click and is not argued with again.

---

## 5. What gets written on first run

1. `~/.quixi/persona.md` — Nora, seeded from the edition's own file, editable, deletable.
2. `~/.mempalace/` — created empty, in the layout above, with the mode the user chose.
3. `~/.quixi/voice.json` — voice off. It stays off until the user turns it on; a microphone that
   opens itself is a bug, and this edition has already had that argument once.
4. A one-line receipt in `~/.quixi/onboarding.json`: which memory mode, which encryption answer,
   and the date. So the next run knows what was chosen instead of guessing.

Nothing else is created, and nothing is created before the choice is made.

---

## 6. Not built yet

This document is the design of record. The first-run screen itself — the greeting, the three memory
options and the encryption question — is a patch that still has to be written against
`crates/quixi-app`, and `chattr +a` has to be applied with the user's confirmation because it changes
permissions on a directory the app then cannot fully manage.

Until that ships, the same sequence is a shell script and a paragraph in the README.
