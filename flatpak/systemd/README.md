# The automatic update

`quixidesk-flatpak.service` runs `flatpak/auto-flatpak.sh --watch` and keeps the installed Flatpak
equal to the newest package in this repository.

```
install -Dm644 flatpak/systemd/quixidesk-flatpak.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now quixidesk-flatpak.service
journalctl --user -u quixidesk-flatpak.service -f      # what it is doing
tail -f ~/.local/state/quixidesk-flatpak.log           # what it built
```

It does not push anything. Building, signing and installing locally are automatic; putting a release in
front of other people is still a decision somebody makes.

There is no `.path` unit. One was tried and it re-fired every six seconds: with a still-existing path
systemd re-arms the oneshot as soon as it exits. A poll every five seconds with a stored package
signature is edge-triggered by construction.
