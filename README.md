# colorbars

A compact, color-coded status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

```
 [Opus 4.6] (48k/1.0M) 📁 Desktop
  ctx: ██▒░░ 48% | 5h: ░░░░░ 4% 3.1h | 7d: ██░░░ 41% 1.2d
```

## Features

- **Model name** — clean display name (parentheticals stripped)
- **Token usage** — compact `48k/1.0M` format with context window percentage
- **Context bar** — 5-cell Unicode bar with partial-fill characters (░▒▓█), color shifts green → yellow → orange → red as usage climbs
- **Git info** — current branch, staged (+N) and modified (~N) file counts
- **Rate limits** — 5-hour and 7-day usage bars with time-until-reset
- **Working directory** — current folder name with 📁 icon
- **ASCII fallback** — set `COLORBARS_BAR_ASCII=1` for `#`/`-` bars instead of Unicode blocks

## Install

```bash
# Download
mkdir -p ~/.claude
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/jcloudlogic/colorbars/main/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

Restart Claude Code — done.

## Requirements

- Python 3 (used by the script internally)
- Git (optional — git info is shown only when inside a repo)

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `COLORBARS_BAR_ASCII` | `false` | Set to `1` or `true` for ASCII-only bars (`###--` instead of `███░░`) |
| `COLORBARS_CTX_TOKENS` | `true` | Set to `0` or `false` to hide the `(48k/1.0M)` token count suffix |

## Color thresholds

| Metric | Green | Yellow | Orange | Red |
|--------|-------|--------|--------|-----|
| Context window | < 40% | 40%+ | 60%+ | 80%+ |
| Rate limits | < 50% | 50%+ | 75%+ | 90%+ |

## Test

```bash
echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/myproject"},"context_window":{"used_percentage":48,"context_window_size":1000000},"cost":{"total_cost_usd":0.5,"total_duration_ms":120000},"rate_limits":{"five_hour":{"used_percentage":4,"resets_at":'$(echo "$(date +%s) + 11160" | bc)'},"seven_day":{"used_percentage":41,"resets_at":'$(echo "$(date +%s) + 103680" | bc)'}}}' | bash ~/.claude/statusline.sh
```

## License

MIT
