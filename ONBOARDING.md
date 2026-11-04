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

## 2. The About block, and why it is worded the way it is

Under the intro there is a panel titled **About Nora**. Two thirds of the way down it has a heading
that answers a question nobody asked out loud: **"But I'm not disabled. Why would I want this?"**

Three things in that answer are deliberate, and each one was argued rather than assumed.

**It does not ask, and it does not check.** Whether someone is disabled, and how, is theirs to say or
to keep. Under the ADA and HIPAA nobody has to hand that over as the price of using software, so the
panel says exactly that and moves on. There is no disability field anywhere in this app, and no
diagnosis is stored, inferred or asked for at any point.

**It names the legal category instead of implying it.** The claim is not "we are nice to disabled
people". It is that a person's own aid is an *auxiliary aid and service*, and that the obligation to
accommodate it sits on the room, not on the person:

- **Title II** — public entities: state and local government, a courthouse, a clerk's window, a school office.
- **Title III** — places of public accommodation: a doctor's office, a pharmacy, a hospital, a lawyer's waiting room.
- **Article III** — a federal court answers to the same rule through **Section 504 of the Rehabilitation Act** (29 U.S.C. § 794), which reaches every program taking federal money, the judiciary included.

**28 CFR 35.160** is the hook that makes it concrete: the entity must furnish appropriate auxiliary aids
and services, and must give primary consideration to the person who will use them. That is the sentence
that turns "bring your own software" into the accommodation rather than a workaround, and it is why the
panel ends with courtrooms, doctors' offices and intake desks instead of a disclaimer.

**It says "assistance device", not "medical device".** "Medical device" is an FDA term with a
regulatory meaning attached, and using it here would hand a hostile reader an easy way to dismiss the
whole claim. The ADA's own vocabulary — assistive technology, auxiliary aid and service — is the one
that actually moves a room, so that is the one on the screen.

The text lives in `resources/ui/app.js`, inside the `first-run-about` panel, and arrives through patch
[`0070-doors`](patches/000-099/070-079/0070-doors.patch) — the header of that patch carries the same
reasoning for anyone reading the code instead of the app. It is **this edition's** copy: `quixidesk-arch`
does not carry it, because Eric's build should look like something upstream would plausibly accept.

![The About Nora panel on first run, at the "But I'm not disabled" heading](screenshots/06-the-about-panel.png)

---

## 3. What a memory palace actually is

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

## 4. Encryption — pick one, or pick none

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

## 5. How memory is allowed to be kept — the actual choice

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

## 6. What gets written on first run

1. `~/.quixi/persona.md` — Nora, seeded from the edition's own file, editable, deletable.
2. `~/.mempalace/` — created empty, in the layout above, with the mode the user chose.
3. `~/.quixi/voice.json` — voice off. It stays off until the user turns it on; a microphone that
   opens itself is a bug, and this edition has already had that argument once.
4. The answers themselves, as app preferences rather than a separate receipt file: `memoryPalacePath`,
   `memoryMode`, `memoryEncryption`, `externalBrowser`. The next run reads those instead of guessing.
   This document originally specified a one-line `~/.quixi/onboarding.json`; the app stores the same
   facts in the preference store it already had, so there is one place to look and no second truth.

Nothing else is created, and nothing is created before the choice is made.

---

## 7. What in this document has shipped, and what is still design

Verified against the running app, not against the plan:

- the first-run flow itself — the intro, **Skip setup**, the provider / key / model / browser / memory /
  encryption table, and **← Back to the start** from every step (`0070-doors`)
- the **About Nora** panel, including the ADA paragraphs in section 2 above
- the encryption choice (none / LUKS / `age`-GPG) and the memory location, written as app preferences
- the persona file and the greeting it ships with (`0044-shipped-persona`, `0087`, `0090`)

Still design, and said so on purpose:

- `chattr +a` on the memory directory. It changes permissions on a directory the app then cannot fully
  manage, so it needs the user's explicit confirmation and is applied by no patch.
- the three-way memory-mode picker as its own step in the first run. The preference key exists and
  Settings writes it; onboarding asks for the path and the encryption, not the mode.

Keeping this list honest matters more than keeping it short. A design document that still claims to be
unbuilt gets read as though it described the binary, and then somebody files a bug against a feature
that was never in it.
