# Personas — a folder, not a registry

Decided 2026-11-02. The persona system stays a **directory of markdown files** and nothing else: no
database, no index, no format of our own. If a person wants to rename, duplicate, back up or delete a
persona, they can do it in Dolphin, in `git`, or with `mv` — and the app will see the result because
it reads the folder.

The persona this edition ships is called **Nora for Github** — the same character as the one running
on the machine that wrote it, named for the copy that ships rather than the copy in use.

## The layout

```
~/.quixi/
  persona.md                  the ACTIVE persona — what the app loads, unchanged
  personas/
    nora.md                   "Nora for Github" — the one this build ships
    pirate.md                 whatever the user writes
    work-mode.md
```

- `persona.md` stays exactly where it is. Everything that reads a persona today — the prompt, the
  top-bar chip, the Settings page — keeps reading it, so this change breaks nothing.
- `personas/*.md` is the shelf. A file on the shelf is a persona you can switch to.
- The **active persona is the file at `persona.md`**, so there is no pointer file to corrupt and no
  second source of truth. Switching copies a shelf file over `persona.md`.

## The four operations

| operation | what it does on disk | why it is safe |
|---|---|---|
| **list** | `readdir personas/` | cannot fail destructively; a missing folder is an empty list |
| **save as** | copy `persona.md` → `personas/<name>.md` | refuses an existing name, so it cannot silently overwrite |
| **switch to** | copy `personas/<name>.md` → `persona.md` | the previous active copy stays on the shelf; nothing is lost |
| **delete** | unlink `personas/<name>.md` | refuses to delete the file that is currently active |

Names are sanitised to a slug (`[a-z0-9-]`), and a name that would escape the directory —
`../../etc/passwd` — is rejected with a test, the same rule the journal already uses for session ids.

## What the UI does with it

The persona chip in the top bar becomes the whole interface:

```
[◐ nora ▾]
   ✓ nora — current persona
   ─────────────────────────
     pirate
     work-mode
     + Save current as…
   ─────────────────────────
     Open the personas folder
     Delete a persona…        asks you to type the name
```

"Open the personas folder" hands the directory to the desktop's own file manager — Dolphin on KDE —
because a folder of markdown does not need a bespoke manager, and the file manager already has rename,
duplicate, compress, permissions and properties.

## Encryption applies to this folder like everything else

A persona is a file like any other, so it inherits whatever was chosen at setup: encrypted disk, an
`age` archive, or nothing with the warning. There is no separate key and no separate format. If someone
chooses "no encryption", the persona files are exactly as readable as the rest of the palace — which is
what the warning on that choice says.

## Not built yet

The four RPCs (`listPersonas`, `savePersonaAs`, `activatePersona`, `deletePersona`) and the menu that
calls them. Today the app holds one file and the chip edits it. The shelf is the next patch, and it is
deliberately small: four filesystem operations and a menu.
