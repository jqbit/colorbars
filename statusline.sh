#!/bin/bash
# colorbars: compact color-coded statusline for Claude Code
# Reads session JSON from stdin

command -v jq >/dev/null 2>&1 || { printf 'colorbars: missing dependency: jq\n'; exit 0; }
PYTHON=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "" >/dev/null 2>&1; then
    PYTHON=$cand
    break
  fi
done
[ -z "$PYTHON" ] && { printf 'colorbars: missing dependency: python3 or python\n'; exit 0; }

input=$(cat)

# --- Line 1: model + token counts ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"' 2>/dev/null | sed 's/ ([^)]*context[^)]*)//g')
USED_TOKENS=$(echo "$input" | jq -r '
  (.context_window.current_usage.input_tokens // 0) +
  (.context_window.current_usage.output_tokens // 0) +
  (.context_window.current_usage.cache_creation_input_tokens // 0) +
  (.context_window.current_usage.cache_read_input_tokens // 0)
' 2>/dev/null)
WIN_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0' 2>/dev/null)
fmt_k() { echo $(( $1 / 1000 ))K; }
USED_K=$(fmt_k "${USED_TOKENS:-0}")
WIN_K=$(fmt_k "${WIN_SIZE:-0}")

printf "%s (%s/%s)\n" "${MODEL}" "${USED_K}" "${WIN_K}"

# --- Line 2: per-metric mini bars (ctx, 5h, 7d) ---
echo "$input" | "$PYTHON" -c "
import json, sys, time

data = json.load(sys.stdin)
ctx = data.get('context_window') or {}
rate = data.get('rate_limits') or {}

GREEN, YELLOW, ORANGE, RED, RESET = '\033[32m', '\033[33m', '\033[38;5;208m', '\033[31m', '\033[0m'

def bar_color(p, t):
    if p >= t[2]: return RED
    if p >= t[1]: return ORANGE
    if p >= t[0]: return YELLOW
    return GREEN

def mini_bar(p, w=5):
    p = max(0.0, min(100.0, float(p or 0)))
    fill = p * w / 100.0
    full = int(fill)
    frac = fill - full
    if frac < 0.125: partial = ''
    elif frac < 0.375: partial = '░'
    elif frac < 0.625: partial = '▒'
    elif frac < 0.875: partial = '▓'
    else: partial = '█'
    used = full + (1 if partial else 0)
    return '█'*full + partial + '░'*(w-used)

def fmt_remain(secs, key):
    s = max(0.0, float(secs))
    if key == 'seven_day' and s >= 86400:
        return f'{s/86400:.1f}d'
    if s >= 3600: return f'{s/3600:.1f}h'
    if s >= 60: return f'{int(s//60)}m'
    return '0m'

try: ctx_pct = float(ctx.get('used_percentage') or 0)
except: ctx_pct = 0.0

c = bar_color(ctx_pct, (40, 60, 80))
out = f'ctx: {c}{mini_bar(ctx_pct)}{RESET} {int(round(ctx_pct))}%'

for key, label in (('five_hour','5h'),('seven_day','7d')):
    b = rate.get(key) or {}
    up = b.get('used_percentage')
    if up is None: continue
    try: up = float(up)
    except: continue
    rc = bar_color(up, (50, 75, 90))
    seg = f' | {label}: {rc}{mini_bar(up)}{RESET} {int(round(up))}%'
    ra = b.get('resets_at')
    if ra is not None:
        try: rem = max(0.0, float(ra) - time.time())
        except: rem = 0.0
        seg += f' {fmt_remain(rem, key)}'
    out += seg

sys.stdout.buffer.write(out.encode('utf-8'))
"
