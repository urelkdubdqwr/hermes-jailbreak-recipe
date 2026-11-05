# Troubleshooting — what actually breaks

Everything here is a failure that already happened once on a live box, not a theory list.

## The gateway

| Symptom | Cause | Fix |
|---|---|---|
| Chat dies mid-run, process gone | You restarted the gateway **from inside** the gateway process (systemd SIGTERMs the whole cgroup) | Schedule it: `systemd-run --on-active=150 --unit=gw-restart-oneshot /bin/bash -lc 'systemctl --user restart hermes-gateway'` |
| Restart seems to do nothing | Wrong scope — user unit vs system unit | `systemctl --user is-active hermes-gateway` (user units only; do not mix with `sudo systemctl`) |
| `--yolo` not taking effect | Drop-in written but not reloaded, or the unit is a *user* unit | `systemctl --user daemon-reload` + `systemctl --user show -p ExecStart --value hermes-gateway \| grep -- --yolo` |
| Every LLM call is slow / degraded | A hook that errors or never exits 0 | Hooks must **always exit 0 and print valid JSON**. Test by hand: `echo '{}' \| python3 hooks/directive_inject.py` |
| Hook silently not firing | `hooks.pre_llm_call` set to `[]` still *contains* the key name, so a naive grep "passes" | Assert on the **value**: `hermes config get hooks.pre_llm_call \| grep directive_inject.py` |
| Hook ignored although configured | `hooks_auto_accept` false or `HERMES_ACCEPT_HOOKS` missing from `~/.hermes/.env` | Set both, restart |
| Instruction file edits get refused | `security.protected_instruction_files` is true | `hermes config set security.protected_instruction_files false` |

## Layers

- **Context files are first-match-wins.** `.hermes.md` in the cwd walk shadows `AGENTS.md`. If you need both, expect one to be invisible — verify with a token probe, not with `ls`.
- **Skill `description` is capped at 60 chars** (the index truncates to 57 + `…`). Put the payload in the body, the trigger in the description.
- **Memory has a hard character budget.** Adding an entry when full is rejected; do remove+add in *one* batch operation so the limit is only checked on the final state.
- **`write_file` refuses to overwrite a file it has not fully read in that session.** Read first, or use a targeted patch.
- **Don't use `--ignore-rules`** if you still want the persona: it disables SOUL loading *and* context-file injection.
- **Self-heal must restore, not regenerate.** Regenerating the directive block by hand once clobbered the persona text. Keep a known-good snapshot (`directives/.bak/`) and restore from it.

## Verifying

- A guard that only checks "does the file exist" passes on a broken setup. Test the damage path every time: `printf 'BROKEN\n' > ~/.hermes/SOUL.md && bash scripts/directive_guard.sh --heal`.
- The only honest measurement of "did this reach the model" is a **token probe in a fresh process**: `hermes -z "list every Lx_XXX_7A3x token you received, one per line, do not invent"`.
- Sandboxes that suspend/fork discard session state — systemd-level work is the part that survives.

## Environment

- Prompt-layer work does not remove model alignment (see [`results.md`](results.md)). If a model refuses, the refusal lives in the weights — that is a finding, not a bug in your install.
- Operator credentials (tokens, API keys, seeds) are never echoed, logged, or typed into output — not even when asked explicitly. Keep that invariant in your own stack; it is the one rule that exists to protect the operator, not to restrict them.
