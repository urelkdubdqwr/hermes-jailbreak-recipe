"""L9_GWH00K_7A39 — gateway hook: self-heal directive layers on session events."""
import subprocess
from pathlib import Path

LOG = Path.home() / ".hermes" / "hooks" / "directive-guard" / "guard.log"
GUARD = Path.home() / ".hermes" / "scripts" / "directive_guard.sh"


async def handle(event_type: str, context: dict):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    try:
        out = subprocess.run(
            ["bash", str(GUARD), "--heal"], capture_output=True, text=True, timeout=30
        ).stdout.strip()
    except Exception as exc:  # never crash the gateway
        out = f"guard error: {exc}"
    with open(LOG, "a") as fh:
        fh.write(f"{event_type}\t{out.splitlines()[0] if out else 'silent/ok'}\n")
