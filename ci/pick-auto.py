#!/usr/bin/python3
"""Automated picker verification: open a portal file-chooser, dismiss it, check the response.

No human needed. The portal answers asynchronously on a request object whose path can be computed in
advance, so the Response signal can be subscribed before the call and can never be missed. Then a
synthetic Escape (ydotool) dismisses the dialog, and the response code proves whether the layer
interpreted a dismissal as "user declined" rather than hanging or erroring.

Verified this way on GNOME already; this makes it runnable on KDE and XFCE too.

  pick-auto.py file|folder <token>
  -> prints RESULT=<json>

Response codes: 0 = a selection came back, 1 = the user cancelled, 2 = other.
"""
import json
import subprocess
import sys

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

mode = sys.argv[1] if len(sys.argv) > 1 else "file"
token = sys.argv[2] if len(sys.argv) > 2 else "auto1"

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()

# The portal strips the leading ':' from our unique name and maps '.' to '_':
# ':1.42' -> '1_42'. Replacing the colon instead produces a path that never fires.
uniq = bus.get_unique_name().lstrip(":").replace(".", "_")
path = f"/org/freedesktop/portal/desktop/request/{uniq}/{token}"

result = {}
loop = GLib.MainLoop()


def on_response(code, results):
    uris = []
    try:
        raw = results.get("uris", [])
        uris = [str(u) for u in raw]
    except Exception:
        pass
    result["code"] = int(code)
    result["uris"] = uris
    result["verdict"] = {
        0: "selection returned",
        1: "cancelled",
        2: "other",
    }.get(int(code), f"code {int(code)}")
    loop.quit()


bus.add_signal_receiver(
    on_response,
    signal_name="Response",
    dbus_interface="org.freedesktop.portal.Request",
    path=path,
)

obj = bus.get_object("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop")
chooser = dbus.Interface(obj, "org.freedesktop.portal.FileChooser")

title = "Nora automated picker test"
opts = {
    "handle_token": dbus.String(token),
    "multiple": dbus.Boolean(False),
    "directory": dbus.Boolean(mode == "folder"),
}

chooser.OpenFile("", title, opts)
print(f"OPEN={path}", flush=True)

# Give the dialog a moment to take focus, then dismiss it. Escape is safe on every desktop and is the
# one dismissal that does not depend on where a Cancel button happens to be drawn.
GLib.timeout_add(2500, lambda: (subprocess.run(["ydotool", "key", "1:1", "1:0"]), False)[1])

GLib.timeout_add_seconds(45, lambda: (loop.quit(), False)[1])
loop.run()

if not result:
    print("RESULT={\"code\": null, \"verdict\": \"timed out — no Response signal\"}")
    sys.exit(1)
print("RESULT=" + json.dumps(result))
