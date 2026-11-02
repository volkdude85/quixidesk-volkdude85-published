# Encryption, for people who just installed this

The memory palace is plain markdown on disk. That is deliberate — you can read it with `cat` — and it
means the protection is your filesystem's job, not the app's. Three layers, cheapest first. You do
not need all three, and doing only the first is a defensible answer.

Every link below was checked live when this was written; a dead or invented link is worse than no
link.

---

## 1. Encrypt the whole disk (do this one)

If the machine is stolen, or someone else has an account on it, this is the difference between "they
have your laptop" and "they have your memory".

- **Arch Wiki — dm-crypt, encrypting an entire system**: https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system
  The long version, and the only one worth following on Arch. `cryptsetup` + LUKS2.
- Most installers (Calamares on Garuda/Endeavour, the Arch `archinstall` script) offer this as a
  checkbox at install time. Turning it on *now* means reinstalling; turning it on later means
  re-encrypting or starting over. It is a decision to make before you put anything in the palace.
- What it costs: nothing day to day. A passphrase at boot, and it has to be one you can still type
  when you are tired. Losing that passphrase loses everything on the disk.

**Do not use the same passphrase here as anywhere else.** This is the one you type with somebody
possibly watching you.

---

## 2. Encrypt the palace on its own

For the cases the disk does not cover: a backup copy, a synced folder, a shared machine, or a machine
whose disk you cannot reinstall.

### age — the simple, modern choice

- https://github.com/FiloSottile/age

```
age-keygen -o key.txt                      # your keypair; keep key.txt OFF this machine
tar czf - ~/.mempalace | age -r <recipient> > palace-$(date +%F).tar.gz.age
```

- One small binary, no key server, no config. A passphrase-protected key is `age -p`.
- Put the public recipient anywhere; put `key.txt` on a USB stick or print it. A key sitting next to
  the archive is not encryption.

### GPG — if you already have keys, or need to encrypt to somebody else

- https://www.gnupg.org/documentation/

More rope than most people need. Fine if you already have a key. If you are starting from nothing,
use `age`.

### sops — secrets inside config files

- https://github.com/getsops/sops

Use this when the thing you are protecting is a config file with API keys in it, not a directory of
markdown. It encrypts the values and leaves the structure readable.

### VeraCrypt — an encrypted container you mount

- https://www.veracrypt.fr/

Cross-platform, drag-and-drop, whole-container encryption. Good when the palace has to travel
between Linux, Windows and macOS, and you want something the other side can open without a shell.
Slower and clunkier than LUKS, which is fine because it is not your boot disk.

---

## 3. Back it up, encrypted

An archive that only exists on one disk is not a backup, and an unencrypted backup is the hole all of
the above is trying to close.

- **restic** — https://restic.net/
  Deduplicating, encrypted, works to a local disk, SFTP, S3 or a cheap storage box. One command:
  `restic -r <repo> backup ~/.mempalace`. This is the one to reach for if you want it to keep working
  without you thinking about it.
- **borgbackup** — https://borgbackup.readthedocs.io/
  Older, very solid, same idea. Either is fine; pick one and actually schedule it.

Whatever you choose: **restore something from it before you trust it.** A backup nobody has restored
is a hope.

---

## 4. What the app is allowed to hold

Three rules, and they are the reason this file exists rather than a key-management feature:

1. **A key the agent can use is a key an attacker who reaches the agent can use.** Anything the app
   can decrypt while you are away is not protected while you are away.
2. **No wallet.** Not a crypto wallet, not a key vault with a custom format. If you already trust a
   password manager or a hardware token, use that; if you do not, `age` with the key on removable
   media is the honest minimum.
3. **Full-disk encryption is the default answer, and the app assumes it.** Everything above layer 1
   is for the case where layer 1 is not available.

---

## 5. The append-only seal is not encryption

Worth separating, because the two get confused:

- `chattr +a` stops files being **deleted or truncated**. It does not stop them being **read**. On a
  disk that is not encrypted, anyone with the disk reads the palace in full.
- It also needs `CAP_LINUX_IMMUTABLE`. An ordinary user cannot set it — measured:
  `chattr: Operation not permitted` — so it has to be applied once with elevation at setup.
  Attributes are documented at
  https://wiki.archlinux.org/title/File_permissions_and_attributes
- Encrypt the disk, *then* seal the directory. Sealing an unencrypted directory makes the record
  permanent without making it private.

---

## 6. The short version

```
1. LUKS on the whole disk at install time          (arch wiki link above)
2. restic (or borg) to somewhere else, encrypted   (link above), and restore one file from it
3. chattr +a on the palace, applied once with sudo (append-only, not encryption)
4. Your passphrase is not reused anywhere, and the key file is not on the same disk
```

That is the whole recommendation. It costs one install-time decision and one scheduled command, and
it is the difference between a memory palace and a liability.

---

## 7. Choosing none is allowed, and the warning is the whole price

Everything above is offered, not required. **"No encryption" is a first-class option** in the setup,
sitting next to the other three rather than hidden behind a "skip" link — because a user who wants it
will find a way to get it anyway, and one who is forced will learn nothing about the risk.

The warning, in the same breath and in these words:

> **Without encryption, anything on this disk can be read by anyone who gets the disk, or anyone with
> an account on this machine.** That includes the memory palace, every conversation in it, and
> anything the agent wrote down about you. A stolen laptop is a complete copy of your history.
>
> It is a real choice: on a desktop that never leaves a locked room, with one account, the risk is
> small and the convenience is genuine. On a laptop that goes to a coffee shop, it is not small.

What the app does with that answer: records it in `~/.quixi/onboarding.json`, shows an unencrypted
badge on the memory page rather than an error, and never asks again unless the user opens the setting.
No nagging, no re-prompting on every launch — a warning repeated becomes wallpaper.
