# Ten minutes on a Deck, and the questions it settles

For whoever has the hardware. Nothing here needs a build, a toolchain, or a checkout — the app is
already published and signed.

**What is already known:** the window fills the panel in Game Mode. Measured under gamescope 3.17 at
1280x800: the app's window reports `1280x800+0+0`, flush to all four edges, nothing clipped.

**What is not known, and what each answer changes:**

| # | Question | If yes | If no |
|---|---|---|---|
| 1 | Does `flatpak install` from this repo work on SteamOS? | the channel is real on Deck | the hub needs a Deck-specific page |
| 2 | Does **STEAM+X** open the keyboard over the composer? | typing works today, no code needed | the whole OSK design changes |
| 3 | Does the app *reach* `steam://open/keyboard` from inside the sandbox? | the button design goes ahead | needs a native helper, not a URL |
| 4 | Does typing land in the composer? | done | WebKit needs an IME path, which is a much bigger job |
| 5 | Does it survive sleep → resume? | Deck-supported | window needs recreating on wake |

---

## The ten minutes

**1. Add the remote and install (Desktop Mode, Konsole).**

```sh
flatpak remote-add --user --if-not-exists quixidesk --from \
  https://volkdude85.github.io/quixidesk-volkdude85-published/io.github.volkdude85.quixidesk.flatpakref
flatpak install --user -y quixidesk io.github.volkdude85.quixidesk
```

Expect about 1.4 GB on the first install — the GNOME 51 runtime is pulled from Flathub, the app itself is
12 MB. **It is not hung.** A cold install on a laptop took 44 seconds; over Wi-Fi on a Deck, give it
several minutes before concluding anything.

**2. Launch it in Desktop Mode and confirm it opens** (`flatpak run io.github.volkdude85.quixidesk`).

**3. Add it to the library for Game Mode.**

```sh
python3 /path/to/quixidesk-repo/scripts/deck-steam-shortcut.py
```

Or by hand: Steam → Games → Add a Non-Steam Game → the `QuixiCore` entry it created.

**4. Switch to Game Mode, launch the tile, then press STEAM+X** and try to type into the message box at
the bottom.

**5. Send the app to sleep** (power button), wake it, and see whether the window comes back.

---

## What to send back

Four lines is plenty:

1. Did the install complete, and roughly how long?
2. Window filled the screen, or bars/clipping?
3. Did STEAM+X bring up the keyboard, and could you type into the box?
4. After sleep and wake — window fine, window blank, or app gone?

Anything that fails is worth more than anything that works, because the working parts are already the
parts with measurements behind them.

---

*Written 2026-11-05. The point of this file is that asking someone to test should cost them ten minutes
and four answers, not an afternoon and a bug report.*
