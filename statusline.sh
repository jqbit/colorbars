#!/bin/bash
python3 -c "
import json, sys, subprocess, os, re, time

data = json.load(sys.stdin)
model_raw = data.get('model', {}).get('display_name', '')
model = re.sub(r'\s*\(.*?\)', '', model_raw).strip() if model_raw else ''
directory = os.path.basename(data.get('workspace', {}).get('current_dir', data.get('cwd', '')))
ctx = data.get('context_window') or {}
raw_pct = ctx.get('used_percentage')
try:
    pct_f = float(raw_pct) if raw_pct is not None else 0.0
except (TypeError, ValueError):
    pct_f = 0.0
pct_f = max(0.0, min(100.0, pct_f))
pct = int(round(pct_f))
cost = data.get('cost', {}).get('total_cost_usd', 0) or 0
duration_ms = data.get('cost', {}).get('total_duration_ms', 0) or 0

# Colors
CYAN, GREEN, YELLOW, ORANGE, RED, RESET = '\033[36m', '\033[32m', '\033[33m', '\033[38;5;208m', '\033[31m', '\033[0m'

def bar_color(pct, thresholds):
    if pct >= thresholds[2]: return RED
    if pct >= thresholds[1]: return ORANGE
    if pct >= thresholds[0]: return YELLOW
    return GREEN

def make_mini_bar(pct, width=5):
    try:
        p = float(pct)
    except (TypeError, ValueError):
        p = 0.0
    p = max(0.0, min(100.0, p))
    if os.environ.get('COLORBARS_BAR_ASCII', '').lower() in ('1', 'true', 'yes'):
        ch_full, ch_empty = '#', '-'
        cells_filled = min(width, max(0, int(p * width / 100.0 + 0.5)))
        return ch_full * cells_filled + ch_empty * (width - cells_filled)
    fill = p * width / 100.0
    full = int(fill)
    frac = fill - full
    if full >= width:
        return '█' * width
    if frac < 0.125:
        partial = ''
    elif frac < 0.375:
        partial = '░'
    elif frac < 0.625:
        partial = '▒'
    elif frac < 0.875:
        partial = '▓'
    else:
        partial = '█'
        full += 0
    used = full + (1 if partial else 0)
    return '█' * full + partial + '░' * (width - used)

def format_compact_tokens(n):
    n = int(n)
    if n >= 1_000_000:
        return f'{n / 1_000_000:.1f}M'
    if n >= 10_000:
        return f'{round(n / 1000)}k'
    if n >= 1_000:
        t = f'{n / 1000:.1f}k'
        if t.endswith('.0k'):
            return t[:-3] + 'k'
        return t
    return str(n)

def used_input_tokens_and_size(ctx):
    if not ctx:
        return None, None
    size = ctx.get('context_window_size')
    cu = ctx.get('current_usage')
    if isinstance(cu, dict):
        used = sum(int(cu.get(k, 0) or 0) for k in ('input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens'))
        if size is not None:
            try:
                return used, int(size)
            except (TypeError, ValueError):
                pass
        return None, None
    if size is not None and ctx.get('used_percentage') is not None:
        try:
            return int(round(float(size) * float(ctx.get('used_percentage')) / 100.0)), int(size)
        except (TypeError, ValueError):
            pass
    return None, None

def format_remaining_short_window(secs):
    s = max(0, int(secs))
    if s >= 3600:
        return f'{s / 3600:.1f}h'
    if s >= 60:
        return f'{s // 60}m'
    return '0m'

def format_rate_remaining(secs, window_key):
    s = max(0.0, float(secs))
    if window_key == 'seven_day' and s >= 86400:
        return f'{s / 86400:.1f}d'
    return format_remaining_short_window(s)

bar = make_mini_bar(pct_f)
ctx_color = bar_color(pct_f, (40, 60, 80))

ctx_tokens_suffix = ''
if os.environ.get('COLORBARS_CTX_TOKENS', '').lower() not in ('0', 'false', 'no'):
    u, cap = used_input_tokens_and_size(ctx)
    if u is not None and cap is not None:
        ctx_tokens_suffix = f' ({format_compact_tokens(u)}/{format_compact_tokens(cap)})'

mins, secs = duration_ms // 60000, (duration_ms % 60000) // 1000

branch = ''
git_status = ''
try:
    subprocess.check_output(['git', 'rev-parse', '--git-dir'], stderr=subprocess.DEVNULL)
    branch = subprocess.check_output(['git', 'branch', '--show-current'], text=True, stderr=subprocess.DEVNULL).strip()
    staged = subprocess.check_output(['git', 'diff', '--cached', '--numstat'], text=True, stderr=subprocess.DEVNULL).strip()
    modified = subprocess.check_output(['git', 'diff', '--numstat'], text=True, stderr=subprocess.DEVNULL).strip()
    staged_count = len([l for l in staged.split('\n') if l]) if staged else 0
    modified_count = len([l for l in modified.split('\n') if l]) if modified else 0
    if staged_count:
        git_status += f'{GREEN}+{staged_count}{RESET}'
    if modified_count:
        git_status += f'{YELLOW}~{modified_count}{RESET}'
except:
    pass

branch_str = f' | 🌿 {branch} {git_status}'.rstrip() if branch else ''

rate = data.get('rate_limits', {})
rate_str = ''
for key, label in (('five_hour', '5h'), ('seven_day', '7d')):
    block = rate.get(key) or {}
    used_pct = block.get('used_percentage')
    if used_pct is None:
        continue
    try:
        used_pct = float(used_pct)
    except (TypeError, ValueError):
        continue
    c = bar_color(used_pct, (50, 75, 90))
    seg = f' | {label}: {c}{make_mini_bar(used_pct)}{RESET} {int(round(used_pct))}%'
    ra = block.get('resets_at')
    if ra is not None:
        try:
            rem = max(0.0, float(ra) - time.time())
        except (TypeError, ValueError):
            rem = 0.0
        seg += f' {format_rate_remaining(rem, key)}'
    rate_str += seg

ctx_str = f'ctx: {ctx_color}{bar}{RESET} {pct}%'
print(f'{CYAN}[{model}]{RESET}{ctx_tokens_suffix} 📁 {directory}{branch_str}')
print(f'{ctx_str}{rate_str}')
"
