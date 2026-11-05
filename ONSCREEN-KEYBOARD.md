# The keyboard in Game Mode

The composer is a text field in a WebKit window. In Desktop Mode a keyboard exists. In Game Mode
(gamescope, no desktop shell) there is nothing to type with until Steam's on-screen keyboard is asked
for. This is the state of that, what the mechanism actually is, and what this build would have to do.

## What Steam actually provides

There is no X11 or Wayland API for "show the Deck's keyboard". Steam owns it, and the only public door
is a URL protocol it registers as a handler:

```
steam://open/keyboard?XPosition=%d&YPosition=%d&Width=%d&Height=%d&Mode=0
steam://close/keyboard
```

That is not folklore. SDL's X11 driver does exactly this — it detects a gamescope session and calls the
deep link when an application asks for text input
(`libsdl-org/SDL`, `src/video/x11/SDL_x11keyboard.c`, around lines 444-453). gamescope's own issue
`ValveSoftware/gamescope#668` documents the same thing from Valve's side, and lists the two options they
saw: talk text-input-v3 through gamescope, or shell out to the `steam://` link. SDL took the second.

So the mechanism is available to any application that can ask the desktop to open a URL. It does not
require Steamworks, and it does not require being a game.

## The manual fallback, which already works today

**STEAM + X** opens the on-screen keyboard on a Deck regardless of what is running, including a
non-Steam application. It is not graceful — it covers the window and has to be dismissed — but it means
the current build is *usable* in Game Mode today, just not comfortable. Anyone testing on a Deck should
know this before concluding that typing is impossible.

## Why this build does not do it yet

Two separate gaps, and they are both small:

**1. A `steam://` URL is treated as a web page.** `openExternal()` in `app.js` posts to the app's
browser-open endpoint, and that endpoint's whole job is choosing a *browser* (a saved preference, a
`.desktop` entry, a Chromium/Firefox candidate list). Handed `steam://open/keyboard`, it picks a browser
and the browser does nothing with it. The endpoint needs one early branch: a non-http scheme goes
straight to `xdg-open`, with no browser preference consulted. Inside the Flatpak, `xdg-open` is Flatpak's
own shim and routes through the session portal, which is what makes it legal from inside the sandbox.

**2. Nothing tells the app it is in Game Mode.** The window has no way to know it is on a Deck. Steam
sets `GAMESCOPE_WAYLAND_DISPLAY` in the environment of what it launches, and gamescope advertises itself
on the X root window; either is a usable signal, and the engine should surface it as one flag the UI can
read.

## The design that should be built, and the one that should not

**Should not:** open the keyboard automatically on focus. That is what SDL does, and it is why Steam
Deck users file bugs about the keyboard covering the screen every time a field is focused
(`ppy/osu#22190`, `libsdl-org/SDL#7160`) — including when a physical keyboard is plugged in, where it is
pure annoyance. The Deck docked to a monitor is a supported way to use this application.

**Should:** a keyboard button in the composer, shown only when the Game Mode flag is set, that calls
`steam://open/keyboard` on press and `steam://close/keyboard` on dismiss. Explicit, dismissable,
invisible when you are not on a handheld. Plus the STEAM+X fallback documented rather than relied on.

## What is still unknown, and needs the hardware

- Whether `xdg-open` inside the Flatpak sandbox can reach the `steam://` handler at all, or whether the
  portal refuses a scheme it does not recognise. **This is the one thing that decides the design**, and
  it can only be settled on a Deck.
- Whether the keyboard positions itself over the composer or covers the whole window at 1280x800.
- Whether typing into WebKit through the OSK behaves, or whether WebKit needs an input-method (IME) path
  that the OSK does not speak to under Xwayland.

Recorded 2026-11-05. The window-fill question in `STEAMDECK.md` is settled; this is the one that decides
whether the Deck is a supported target or a curiosity.
