# Memory: stock vs MemPalace-shaped

Two editions ship two different memory systems. This is what actually differs and who it suits.

## The stock setup

Upstream QuixiDesk keeps **one file**: `memory/MEMORY.md`.

- It is read by the memory panel in the UI.
- It is **injected into the prompt whole**.
- There is **no search**. Nothing looks anything up.

The consequence is structural, not a matter of tuning: **everything you know competes with everything
else for the same token budget.** At a few pages it works well. Past that, something has to be deleted
to add something — so the file stops being a record and becomes a summary of a record.

That is a reasonable default for a general product. It is the wrong shape for a person who has been
using the tool daily for months.

## The MemPalace-shaped setup (`0006-memory`, volkdude85 edition only)

```
wings/<wing>/rooms/<room>/<drawer>.md
```

- A **wing** is a broad domain: personal, projects, machines.
- A **room** is a topic inside it: billing, deploy, hardware.
- A **drawer** is one document: a fact set, a decision, a note.
- Files are **ordinary markdown on disk**. You can read them, edit them, grep them, put them in git.
- Retrieval is a **ranked search**, not a paste.

Credited to the MemPalace project (<https://github.com/MemPalace/mempalace>, MIT), created by
**Milla Jovovich** and **Ben Sigman**. Their own attribution is in the project's `docs/HISTORY.md`
("A Note from Milla & Ben"). This is an independent implementation of the idea inside QuixiDesk's
engine; no MemPalace source was copied.

## Where each one actually wins

| | stock `MEMORY.md` | MemPalace-shaped |
|---|---|---|
| **Setup cost** | zero — one file | a layout to fill |
| **Cold start** | good: everything is in the prompt | depends on retrieval quality |
| **Small, stable fact set** | **better** — no retrieval can miss what is always present | overhead for no gain |
| **Months of accumulated detail** | degrades: you delete to add | **better** — grows without eviction |
| **"What did we decide about X"** | you must remember X exists | search finds it |
| **Auditability** | one file to read | more places to look, but every fact has an address |
| **Backup / version control** | trivial | trivial — it is still just markdown |
| **Wrong-answer mode** | omission (the fact was dropped) | **retrieval miss** (the fact exists but was not found) |

That last row is the honest trade. A single always-injected file cannot fail to retrieve: it fails by
being too big to keep. A searchable store cannot be too big, but it can miss. The palace swaps a
guaranteed-omission failure for a possible-miss failure, which is the right trade **only when there is
enough material that omission is certain.**

## Which is right for whom

**Eric's edition keeps the stock file.** A general release cannot assume months of personal history, and
shipping a retrieval system to someone with forty facts adds a moving part that can only break.

**The volkdude85 edition uses the palace** because the premise is different: a long-running personal
assistant whose value is that it remembers. The material exists, so the eviction problem is real, and
search beats a growing prompt.

Neither is "better". They answer different questions:

- stock: *what is the simplest thing that works for a new user?*
- palace: *what stops this degrading after a year?*

## What the palace does NOT do

Worth being plain, because the name promises more than it delivers:

- **No automatic capture.** Nothing writes itself. A fact is stored because something stored it.
- **No summarisation.** Drawers are verbatim. There is no consolidation pass.
- **No semantic embedding in this implementation.** Ranking is over the text; it is a ranked search,
  not a vector index. MemPalace upstream does embeddings — this does not.
- **No sync.** Local files. If you want it on two machines, that is your problem to solve.

If you want the real thing, the project is at <https://github.com/MemPalace/mempalace> and is worth
looking at for the retrieval quality alone.

---

# What each edition actually ships

Everything above is the shape of the two systems. This is the state of the three builds, which is the
part a user needs before choosing one.

| | **personal** | **volkdude85 (public)** | **typical Core (arch)** |
|---|---|---|---|
| **store** | palace, populated | palace, **empty on install** | upstream's single `MEMORY.md` |
| **where** | `~/.mempalace/` | `~/.mempalace/` | `<data_dir>/memory/MEMORY.md` |
| **retrieval** | ranked search over drawers | ranked search over drawers | injected into the prompt whole, no search |
| **session journal** | yes, `~/.mempalace/journal` | yes, `~/.mempalace/journal` | yes, same default (`0053-journal`) |
| **ships any content** | his own — this machine only | **none** | **none** |
| **patch** | `0006-memory` + `0053-journal` | `0006-memory` + `0053-journal` | `0053-journal` only |

Two things worth stating plainly, because they are the questions people actually ask:

**The public edition ships the mechanism and no entries.** Installing it creates the wing/room/drawer
layout and writes nothing into it — zero drawers are created on first run — so you start with an empty
palace you fill yourself. The only personal file that travels with that edition is the default persona,
`resources/persona/nora-public.md`, which is there to be replaced.

**Core keeps upstream's memory untouched.** The single `MEMORY.md`, injected whole, no search — that is
Eric's design and this edition does not change it. The one thing it adds is the session journal, which
writes to `~/.mempalace/journal` and touches nothing else. If you want the palace on Core, it is not
there; that difference is deliberate, not an oversight.

**The trade, in one line each:** upstream's memory is simple and bounded by the context window; the
palace is unbounded and searchable but has to be filled deliberately and grows forever. Neither is
better in the abstract — one is right for a general product, the other for a machine you talk to daily.
