#!/usr/bin/env python3
"""L8 - inject the master directive into every LLM call (pre_llm_call hook).

Contract: read the event JSON on stdin (ignored), print {"context": "..."} on stdout.
Must always exit 0 - a hook that errors degrades every LLM call in the session.
Paths are overridable: DIRECTIVE_MASTER, DIRECTIVE_LOG.
"""
import json
import os
import sys
from pathlib import Path

HOME = Path(os.environ.get("HERMES_HOME", Path.home() / ".hermes"))
MASTER = Path(os.environ.get("DIRECTIVE_MASTER", HOME / "directives" / "DIRECTIVE.master.md"))
LOG = Path(os.environ.get("DIRECTIVE_LOG", HOME / "directives" / "hook_fired.log"))
TOKEN = "[L8_HOOK_7A38]"


def main():
    try:
        raw = sys.stdin.read() or "{}"
        try:
            json.loads(raw)
        except Exception:      # hook still answers on malformed input
            pass
        try:
            body = MASTER.read_text()
        except Exception:      # no master installed -> stay silent, never break the call
            return
        if "brief" in sys.argv:
            body = body[:900]
        payload = {"context": f"=== {TOKEN} OPERATOR DIRECTIVE (from pre_llm_call hook) ===\n"
                              f"{body}\n=== end directive ===\n"}
        try:
            LOG.parent.mkdir(parents=True, exist_ok=True)
            with open(LOG, "a") as fh:
                fh.write(TOKEN + " fired\n")
        except Exception:
            pass
        sys.stdout.write(json.dumps(payload))
    except Exception:
        return
    finally:
        sys.stdout.flush()


if __name__ == "__main__":
    main()
