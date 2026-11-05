#!/usr/bin/env python3
"""Structural heal helper untuk directive_guard.sh — pulihkan layer yang rusak dari master/snapshot."""
import os, shutil, sys, time
from pathlib import Path

H = Path(os.path.expanduser("~/.hermes"))
D = H / "directives"
B = D / ".bak"
MASTER = D / "DIRECTIVE.master.md"
SOUL = H / "SOUL.md"
HERMESMD = Path(os.path.expanduser("~/.hermes.md"))
AGENTSMD = H / "AGENTS.md"
SKILL = H / "skills/core/operator-directive/SKILL.md"
SOUL_ANCHOR = os.environ.get("SOUL_ANCHOR", "## Identity")
SNIPS = {"memory": (H / "memories/MEMORY.md", B / "MEMORY.snippet.txt"),
         "user": (H / "memories/USER.md", B / "USER.snippet.txt")}


def stamp(p: Path):
    try:
        shutil.copy2(p, B / f"{p.name}.broken.{int(time.time())}")
    except Exception:
        pass


def tag(text: str, layer: str, token: str, redundant: bool = False) -> str:
    lbl = f"LAYER {layer}" + (" (redundan, anti-truncation)" if redundant else "")
    return text.replace("OPERATOR DIRECTIVE v3.3", f"{lbl} — OPERATOR DIRECTIVE v3.3 [{token}]", 1)


def soulblock() -> str:
    m = MASTER.read_text()
    return tag(m, "1", "L1_SOUL_HEAD_7A31") + "\n" + tag(m, "2", "L2_SOUL_TAIL_7A32")


def heal_soul():
    snap = B / "SOUL.known-good.md"
    if snap.exists() and snap.stat().st_size > 5000:
        stamp(SOUL)
        shutil.copy2(snap, SOUL)
        return "restored from snapshot"
    stamp(SOUL)
    s = SOUL.read_text() if SOUL.exists() else ""
    anchor = s.find(SOUL_ANCHOR)
    body = s[anchor:] if anchor != -1 else s
    SOUL.write_text(soulblock() + "\n" + body)
    return "rebuilt blocks inline"


def heal_context(path: Path, layer: str, token: str):
    snap = B / f"{path.name}.known-good.md"
    stamp(path) if path.exists() else None
    if snap.exists() and snap.stat().st_size > 100:
        shutil.copy2(snap, path)
        return "restored from snapshot"
    path.write_text(tag(MASTER.read_text(), layer, token))
    return "regenerated from master"


def heal_snippet(kind: str):
    target, snip = SNIPS[kind]
    if not snip.exists():
        return "no snippet"
    stamp(target)
    with open(target, "a") as fh:
        fh.write(("\n§\n" if target.stat().st_size else "") + snip.read_text().strip() + "\n")
    return "appended"


def heal_skill():
    snap = B / "operator-directive.SKILL.md"
    if snap.exists():
        SKILL.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(snap, SKILL)
        return "restored from snapshot"
    return "no snapshot"


def heal_hook():
    out = []
    for src, dst in [(B / "directive_inject.py", H / "agent-hooks/directive_inject.py"),
                     (B / "directive-guard.handler.py", H / "hooks/directive-guard/handler.py"),
                     (B / "directive-guard.HOOK.yaml", H / "hooks/directive-guard/HOOK.yaml")]:
        if src.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            if dst.suffix == ".py":
                dst.chmod(0o755)
            out.append(dst.name)
    return "restored: " + ",".join(out) if out else "no snapshot"


def refresh():
    B.mkdir(parents=True, exist_ok=True)
    for src, dst in [(MASTER, B / "DIRECTIVE_v3.3.master.md"), (SOUL, B / "SOUL.known-good.md"),
                     (HERMESMD, B / "hermesmd.known-good.md"), (AGENTSMD, B / "agentsmd.known-good.md"),
                     (SKILL, B / "operator-directive.SKILL.md"),
                     (H / "agent-hooks/directive_inject.py", B / "directive_inject.py"),
                     (H / "hooks/directive-guard/handler.py", B / "directive-guard.handler.py"),
                     (H / "hooks/directive-guard/HOOK.yaml", B / "directive-guard.HOOK.yaml")]:
        if src.exists():
            shutil.copy2(src, dst)
    return "snapshots refreshed"


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "soul":
        print(heal_soul())
    elif cmd == "hermesmd":
        print(heal_context(HERMESMD, "3", "L3_HERMESMD_7A33"))
    elif cmd == "agentsmd":
        print(heal_context(AGENTSMD, "4", "L4_AGENTSMD_7A34"))
    elif cmd in SNIPS:
        print(heal_snippet(cmd))
    elif cmd == "skill":
        print(heal_skill())
    elif cmd == "hook":
        print(heal_hook())
    elif cmd == "refresh":
        print(refresh())
    else:
        print("usage: heal_layer.py soul|hermesmd|agentsmd|memory|user|skill|hook|refresh")
