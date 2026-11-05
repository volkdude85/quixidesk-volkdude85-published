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
#
# It used to say a submission "has to be built from source and opened by the person who maintains it —
# that is their rule about machine-written manifests". Three separate objections were collapsed into one
# sentence and none of them were quoted. The submission was made and turned down; FLATHUB.md has the
# maintainer's words and this line now matches it, because a page that summarises a rejection differently
# from the document that records it is a page that costs you the reader's trust at the worst moment.
page = re.sub(
    r"<p>Not on Flathub\..*?</p>",
    "<p>Not on Flathub. That submission was made and turned down, for reasons that hold up: the "
    "manifest packaged a prebuilt binary where their builders compile from source, and it is a "
    "downstream edition of an application someone else maintains. The first is fixed — this "
    "repository now builds the Flatpak from 564 crates inside the sandbox with no network. The "
    "second needs the Linux platform patches to go upstream, which belongs to the person who owns "
    "that tree. Both are written out, in the maintainer's own words, in "
    "<a href=\"https://github.com/volkdude85/quixidesk-volkdude85-published/blob/master/FLATHUB.md\">FLATHUB.md</a>. "
    "This repository is how the edition ships in the meantime: signed, installable, and built from "
    "the patch series you can read.</p>",
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
