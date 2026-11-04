#!/usr/bin/python3
"""Rebuild site/index.html: current id, current runtime, and the recording in his own words.

The transcript is inserted mechanically from voice/quixidesk-voice.txt so no word can be
dropped or retyped. Only the line breaking is ours.
"""
import html
import re

TXT = "voice/quixidesk-voice.txt"
PAGE = "site/index.html"

raw = open(TXT).read().strip()
raw = re.sub(r"\s+", " ", raw)
# split into sentences, keep the terminators
sent = re.findall(r"[^.!?]+[.!?]+(?:\s|$)|[^.!?]+$", raw)
sent = [s.strip() for s in sent if s.strip()]

paras, buf = [], []
for s in sent:
    buf.append(s)
    if len(buf) >= 3:
        paras.append(" ".join(buf))
        buf = []
if buf:
    paras.append(" ".join(buf))

body = "\n".join("  <p>%s</p>" % html.escape(p) for p in paras)

section = """
<hr>

<h2>In my own words</h2>
<p>The recording is the description. It was not scripted and it has not been cut — this is the
transcript, unedited, including where I correct myself in the middle of it. The transcriber's
spelling of the product name is the transcriber's.</p>

<audio controls preload="metadata" src="voice/quixidesk-voice.webm" style="width:100%%"></audio>
<p><a href="voice/quixidesk-voice.webm">voice/quixidesk-voice.webm</a> — 6 min 37 s ·
<a href="voice/quixidesk-voice.txt">the raw transcript</a></p>

<div class="transcript">
%s
</div>
""" % body

page = open(PAGE).read()

# current identity everywhere
page = page.replace("org.quixidesk.QuixiDesk", "io.github.volkdude85.quixidesk")
page = page.replace("org.gnome.Platform//50", "org.gnome.Platform//51")
page = page.replace("runtime</td><td><code>org.gnome.Platform//51</code>",
                    "runtime</td><td><code>org.gnome.Platform//51</code>")

# the note about Flathub, told straight
page = re.sub(
    r"<p>Not on Flathub\..*?</p>",
    "<p>Not on Flathub. A submission there has to be built from source inside the sandbox and "
    "opened by the person who maintains it — that is their rule about machine-written manifests, "
    "and it is a fair one. This repository is how the edition ships instead: signed, installable, "
    "and built from the patch series you can read.</p>",
    page, flags=re.S)

if "</div>\n\n</body>" not in page:
    page = page.replace("</body>", section + "\n</body>")

# a little styling for the transcript block
page = page.replace("  a { color: inherit; }",
                    "  a { color: inherit; }\n"
                    "  .transcript p { margin: .85rem 0; }\n"
                    "  .transcript { border-left: 2px solid rgba(127,127,127,.35); padding-left: 1rem; }")

open(PAGE, "w").write(page)
print("paras:", len(paras), "| words:", len(raw.split()))
