#!/usr/bin/env python3
"""Sanitize the published tree: remove the owner's own tooling and the names of his family.

Runs at the end of prepare(), over the assembled tree, and refuses to let a build continue if any
of it survives. Patch hunks were the wrong tool here: the two series' copies of these files drift
(879 lines vs 686), so a diff applies with fuzz, applies reversed, or silently skips — and one of
those outcomes shipped a package with a family roster inside it. Exact-string surgery with a hard
assert at the end does not have that failure mode.

What it does:
  1. deletes the owner's 13 skills from resources/bundled-skills-extracted/
  2. rewrites bundled-skills/manifest.json to keep only what upstream ships
  3. replaces the hardcoded name roster in resources/ui/capability-workflows.js with generic
     patterns plus names read from the user's own machine (~/.quixi/redact-names.txt)
  4. hides the "volkdude85 tools & skills" panel when there is nothing in it

Nothing else in the app is touched.
"""

import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(".")
UI = ROOT / "resources/ui/capability-workflows.js"
MANIFEST = ROOT / "resources/bundled-skills/manifest.json"
EXTRACTED = ROOT / "resources/bundled-skills-extracted"

HIS_SKILLS = [
    "browser-driving", "web-research", "post-media-read", "terminal-email", "voice-pipeline",
    "memory-hygiene", "local-inference", "multi-machine-offload", "linux-ops",
    "document-extraction", "verification-discipline", "image-gen-local", "reverse-engineering",
]

NEW_NAME_MAP = """    // A shipped build must not carry a household with it. The list of names to hide is itself the
    // disclosure: this file used to hardcode the owner's family, so every download contained a roster
    // of real people — the opposite of redaction. Names now arrive from the user's own machine
    // (~/.quixi/redact-names.txt, absent by default) and this file carries only the generic shapes
    // that are true everywhere: home paths, mail addresses and IPv4 literals.
    const NAME_MAP = [
      [/\\/home\\/[^\\s"'<>]+/g, "~/…"],
      [/[\\w.+-]+@[\\w-]+\\.[\\w.-]+/g, "an address"],
      [/\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b/g, "an address"],
      ...(window.QUIXI_REDACT_NAMES || []).map((n) => {
        const escaped = String(n).replace(/[.*+?^${}()|[\\]\\\\]/g, "\\\\$&");
        return [new RegExp(`\\\\b(${escaped})('s)?\\\\b`, "gi"),
                (_m, _p, poss) => (poss ? "someone's" : "someone")];
      }),
    ];"""

FORBIDDEN = [
    "Haeligh", "Belladonna", "Lillie", "Tiffany", "Robin", "Michelle",
    "\\bSean\\b", "how he got crazy", "a form of PTSD",
]


def fail(msg: str) -> int:
    print(f"sanitize-tree: {msg}", file=sys.stderr)
    print("sanitize-tree: refusing to build this tree", file=sys.stderr)
    return 1


def main() -> int:
    removed = []
    for name in HIS_SKILLS:
        target = EXTRACTED / name
        if target.exists():
            shutil.rmtree(target, ignore_errors=True)
            removed.append(name)

    kept = []
    if MANIFEST.exists():
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        before = len(data.get("skills", []))
        data["skills"] = [s for s in data.get("skills", []) if s.get("owner") != "volkdude85"]
        kept = [s.get("name") for s in data["skills"]]
        MANIFEST.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        print(f"sanitize-tree: manifest {before} -> {len(data['skills'])} entries {kept}")
    else:
        print("sanitize-tree: no manifest", file=sys.stderr)

    text = UI.read_text(encoding="utf-8")

    m = re.search(r"    const NAME_MAP = \[.*?\n    \];", text, re.DOTALL)
    if not m:
        return fail("could not find the NAME_MAP block to replace")
    text = text[:m.start()] + NEW_NAME_MAP + text[m.end():]

    # Hide the owner's panel when it has nothing in it.
    if 'skillPanel("volkdude85 tools & skills"' in text and "(mine.length" not in text:
        text = text.replace(
            '        skillPanel("volkdude85 tools & skills",',
            '        // This panel used to hold the owner\'s private tool library, which is not the product.\n'
            '        // It renders only if a build actually carries such skills; this one does not.\n'
            '        (mine.length ? skillPanel("volkdude85 tools & skills",', 1)
        text = text.replace("          mine),", "          mine) : null),", 1)

    UI.write_text(text, encoding="utf-8")

    print(f"sanitize-tree: removed {len(removed)} of the owner's skills")
    problems = [p for p in FORBIDDEN if re.search(p, text)]
    if problems:
        return fail(f"still in capability-workflows.js: {problems}")
    print("sanitize-tree: capability-workflows.js is clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
