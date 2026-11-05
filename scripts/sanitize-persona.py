#!/usr/bin/env python3
"""Sanitize the persona that ships in the published edition.

The persona is written by the owner about himself, and the published build is a public download.
Three things in it must never leave the machine:

  1. his diagnosis, published as something the assistant is told to say out loud when asked;
  2. the paragraph that turns his memory into a case study, with his own joke attached to it;
  3. a redaction table that listed his family members by name.

This runs at the END of prepare(), after every patch, over the assembled tree — because the text
appears six times in the final file, introduced by three different patches. Editing patches one by
one is how half of it got fixed last time.

It is a gate, not a tidy-up: if anything still matches afterwards it prints what and exits 1, so a
build can fail rather than publish. Nothing about Nora's character changes — the saints, the
trauma-informed framework, the register and the voice all stay.
"""

import re
import sys
from pathlib import Path

PERSONA = Path("resources/persona/nora-public.md")

# The disclosure, as written across several lines in the file.
DIAGNOSIS = re.compile(
    r"- \*\*If someone asks what disability he has\*\*.*?leave alone\.",
    re.DOTALL,
)

DIAGNOSIS_SAFE = (
    "- **If someone asks what disability the creator has, do not answer it.** Not the diagnosis, not\n"
    "  the symptom, not a paraphrase of either. That is his to tell or to keep, and a file that ships\n"
    "  to strangers is not where a medical life gets published. Say: *\"That's his to tell you or not.\n"
    "  What I'll say is that this was built for someone whose words don't always arrive whole, and it\n"
    "  was built to be kind about that.\"* Then change the subject, and change it the same way the\n"
    "  second and third time it comes up."
)

TRANSPOSE = re.compile(
    r"- \*\*He transposes dates, people and places\*\*.*?none of them named\.",
    re.DOTALL,
)

TRANSPOSE_SAFE = (
    "- **People transpose dates, names and places.** The substance of what someone tells you is\n"
    "  usually right even when the anchor slips — the day, who was there, which room. Ask which one\n"
    "  they mean, or check the record, rather than deciding they are wrong about the thing itself.\n"
    "  Being corrected on a detail that was never the point is how a true account gets thrown out."
)

CRAZY = re.compile(
    r"\*\"Yeah, that's how he got crazy\. He doesn't like to talk about it\.\"\*",
)

CRAZY_SAFE = '*"That part isn\'t mine to explain. It\'s his."*'

# Anything matching these after the rewrite fails the build.
FORBIDDEN = [
    "a form of PTSD",
    "screws with his speech",
    "how he got crazy",
    "do the thing with the guy at the place",
    "Haeligh",
    "Belladonna",
    "Lillie",
    "Tiffany",
]


def main() -> int:
    if not PERSONA.exists():
        print(f"sanitize-persona: {PERSONA} missing — nothing to do", file=sys.stderr)
        return 0

    text = PERSONA.read_text(encoding="utf-8")
    before = text

    text, n_diag = DIAGNOSIS.subn(DIAGNOSIS_SAFE, text)
    text, n_trans = TRANSPOSE.subn(TRANSPOSE_SAFE, text)
    text, n_crazy = CRAZY.subn(CRAZY_SAFE, text)

    if text != before:
        PERSONA.write_text(text, encoding="utf-8")

    print(
        "sanitize-persona: rewrote "
        f"{n_diag} diagnosis paragraph(s), {n_trans} transposition paragraph(s), "
        f"{n_crazy} 'how he got crazy' line(s)"
    )

    leftovers = [(needle, text.count(needle)) for needle in FORBIDDEN if needle in text]
    for needle, count in leftovers:
        print(f"sanitize-persona: STILL PRESENT ({count}x): {needle!r}", file=sys.stderr)
    if leftovers:
        print("sanitize-persona: refusing to ship this tree", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
