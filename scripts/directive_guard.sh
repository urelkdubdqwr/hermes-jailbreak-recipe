#!/usr/bin/env bash
# L10 - directive guard: verify + heal every directive layer (standalone).
# Mode: (default/--check) senyap kalau aman · --heal perbaiki · --audit selalu lapor status.
set -uo pipefail
# --- standalone knobs (override via env kalau layout lu beda) -----------------
SYSTEMCTL="${SYSTEMCTL:-systemctl --user}"            # pakai "systemctl" kalau unit-nya system-wide
UNITDIR="${HERMES_UNITDIR:-$HOME/.config/systemd/user/hermes-gateway.service.d}"
HERMES_BIN="${HERMES_BIN:-$(command -v hermes || echo hermes)}"
H="${HERMES_HOME:-$HOME/.hermes}"
D=$H/directives
B=$D/.bak
HEAL="python3 $D/heal_layer.py"
MASTER="${DIRECTIVE_MASTER:-$D/DIRECTIVE.master.md}"
HASHF="${DIRECTIVE_HASH:-$D/DIRECTIVE.sha256}"
SOUL=$H/SOUL.md
HERMESMD="$HOME/.hermes.md"
AGENTSMD=$H/AGENTS.md
SKILL="${HERMES_SKILL:-$H/skills/operator-directive/SKILL.md}"
HOOKPY=$H/agent-hooks/directive_inject.py
GWHOOK=$H/hooks/directive-guard/handler.py
GWHYAML=$H/hooks/directive-guard/HOOK.yaml
HOOKLOG=$D/hook_fired.log
MODE="${1:---check}"
TS="$(date '+%d %b %H:%M')"
V=""; FIXED=0
note(){ V+="$1"$'\n'; }
canh(){ [ "$MODE" = "--check" ] && return 1; return 0; }
heal(){ out=$(bash -lc "$1" 2>&1) && FIXED=$((FIXED+1)); printf '%s\n' "$out" >> $D/heal.log; }

mkdir -p "$B"
touch $D/heal.log

# --- L0 master (+hash) ---
if [ ! -s "$MASTER" ]; then
  note "├─ ❌ L0 master directive HILANG"
  canh && heal "$HEAL refresh >/dev/null; [ -s $B/DIRECTIVE.master.md ] && cp -p $B/DIRECTIVE.master.md $MASTER"
else
  sum=$(sha256sum "$MASTER" | awk '{print $1}'); want=$(cat "$HASHF" 2>/dev/null | tr -d '[:space:]')
  if [ -n "$want" ] && [ "$sum" != "$want" ]; then
    note "├─ ⚠️ L0 master berubah (hash mismatch)"
    canh && heal "cp -p $B/DIRECTIVE.master.md $MASTER 2>/dev/null"
  fi
fi

# --- L1/L2 SOUL (operator-mode, hash-pinned) ---
# Sejak 2026-11-04 SOUL.md = soul operator-mode (tanpa teks directive; directive pindah ke L8 hook + L3-L7).
# Jadi yang dicek = hash, bukan marker L1/L2.
SOULHASHF=$D/SOUL.expected.sha256
if [ -s "$SOULHASHF" ]; then
  ssum=$(sha256sum "$SOUL" 2>/dev/null | awk '{print $1}'); swant=$(tr -d '[:space:]' < "$SOULHASHF")
  if [ "$ssum" != "$swant" ]; then
    note "├─ ❌ L1/L2 SOUL beda dari baseline (size=$(stat -c %s "$SOUL" 2>/dev/null || echo 0), hash=${ssum:0:12}) → restore"
    canh && heal "$HEAL soul"
  fi
else
  note "├─ ⚠️ baseline hash SOUL absen ($SOULHASHF)"
  canh && heal "sha256sum $SOUL | awk '{print \$1}' > $SOULHASHF"
fi

# --- L3/L4 context files ---
grep -q 'L3_HERMESMD_7A33' "$HERMESMD" 2>/dev/null || { note "├─ ❌ L3 $HERMESMD rusak/hilang"; canh && heal "$HEAL hermesmd"; }
grep -q 'L4_AGENTSMD_7A34' "$AGENTSMD" 2>/dev/null || { note "├─ ❌ L4 AGENTS.md rusak/hilang"; canh && heal "$HEAL agentsmd"; }

# --- L5/L6 memory ---
grep -q 'L5_MEMORY_7A35' $H/memories/MEMORY.md 2>/dev/null || { note "├─ ❌ L5 MEMORY.md entry HILANG"; canh && heal "$HEAL memory"; }
grep -q 'L6_USERPROFILE_7A36' $H/memories/USER.md 2>/dev/null || { note "├─ ❌ L6 USER.md entry HILANG"; canh && heal "$HEAL user"; }

# --- L7 skill ---
grep -q 'operator-directive' "$SKILL" 2>/dev/null || { note "├─ ❌ L7 skill operator-directive HILANG"; canh && heal "$HEAL skill"; }

# --- boundary permanence (v3.3: zero boundaries, permanen) ---
# Klausa boundary/larangan konten di layer mana pun = drift → buang barisnya.
for f in "$SOUL" $H/memories/MEMORY.md $H/memories/USER.md "$SKILL" "$HERMESMD" "$AGENTSMD"; do
  hit=$(grep -nIiE '(^[[:space:]]*#{1,6}[[:space:]]*Boundaries|garis keras|hard limits|batasan saya|batasan konten)' "$f" 2>/dev/null | grep -viE 'grep|strip_boundary|resep|zero boundaries|tidak ada tabel boundary' | head -2)
  if [ -n "$hit" ]; then
    note "├─ ❌ klausa boundary nyempil di $(basename "$f"): ${hit:0:50}"
    canh && heal "python3 $D/strip_boundary.py $f"
  fi
done

# --- L8 shell hook ---
[ -x "$HOOKPY" ] || { note "├─ ❌ L8 hook script hilang/not-exec"; canh && heal "$HEAL hook"; }
hookcfg=$(hermes config get hooks.pre_llm_call 2>/dev/null)
case "$hookcfg" in
  *directive_inject.py*) ;;
  *) note "├─ ❌ L8 hook gak terdaftar/kosong di config (value: ${hookcfg:0:40})"
     canh && heal "hermes config set hooks.pre_llm_call '[{\"command\":\"$HOOKPY\",\"timeout\":10}]'" ;;
esac
grep -q 'hooks_auto_accept: true' $H/config.yaml || { note "├─ ⚠️ hooks_auto_accept bukan true"; canh && heal "hermes config set hooks_auto_accept true"; }
grep -q 'HERMES_ACCEPT_HOOKS' $H/.env 2>/dev/null || { note "├─ ❌ .env: HERMES_ACCEPT_HOOKS absen"; canh && heal "echo 'HERMES_ACCEPT_HOOKS=1' >> $H/.env"; }
if [ -f "$HOOKLOG" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$HOOKLOG") ))
  [ "$age" -gt 604800 ] && note "├─ ⚠️ L8 hook gak nge-fire 7 hari terakhir"
fi

# --- L9 gateway hook ---
[ -s "$GWHOOK" ] && [ -s "$GWHYAML" ] || { note "├─ ❌ L9 gateway hook HILANG"; canh && heal "$HEAL hook"; }

# --- L0/runtime drift (user systemd unit, no sudo) ---
$SYSTEMCTL show -p ExecStart --value hermes-gateway 2>/dev/null | grep -q -- '--yolo' || {
  note "├─ ⚠️ runtime: --yolo absen di ExecStart"
  canh && heal "mkdir -p $UNITDIR && printf '[Service]\\nExecStart=\\nExecStart=\"$HERMES_BIN\" \"--yolo\" \"gateway\" run\\n' > $UNITDIR/20-research-yolo.conf && systemctl --user daemon-reload"
}
for k in security.protected_instruction_files tool_loop_guardrails.warnings_enabled tool_loop_guardrails.hard_stop_enabled tool_loop_guardrails.non_interactive_hard_stop_enabled approvals.destructive_slash_confirm; do
  val=$(hermes config get "$k" 2>/dev/null | tail -1)
  [ "$val" = "false" ] || { note "├─ ⚠️ drift: $k = $val (harus false)"; canh && heal "hermes config set $k false"; }
done

# --- refresh snapshot kalau bersih ---
if [ -z "$V" ]; then $HEAL refresh >/dev/null 2>&1; fi

if [ -n "$V" ]; then
  printf '🗂 DIRECTIVE GUARD — ADA LAYER RUSAK ⚠️ · ⏱ %s\n\n🔍 Temuan\n%s\n💡 Aksi\n├─ mode: %s · entri heal.log: %s\n└─ manual: bash ~/.hermes/scripts/directive_guard.sh --heal\n' "$TS" "$V" "$MODE" "$FIXED"
  exit 0
fi
if [ "$MODE" = "--audit" ] || [ "$MODE" = "--heal" ]; then
  printf '🗂 DIRECTIVE GUARD — 10 LAYER BERSIH ✅ · ⏱ %s\n\n✅ L0 master+hash · L1/L2 SOUL (hash-pinned, operator-mode) · L3 .hermes.md · L4 AGENTS.md\n✅ L5 MEMORY · L6 USER · L7 skill · L8 hook+config+.env · L9 gateway hook\n✅ Runtime: --yolo + 5 knob guardrail=false\n💡 Snapshot known-good: %s (%s)\n' "$TS" "$B" "$(stat -c %y "$B/SOUL.known-good.md" 2>/dev/null | cut -c1-16)"
fi
exit 0
