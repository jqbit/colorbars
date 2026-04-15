# colorbars

Compact, color-coded status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

```
Opus 4.6 (48K/1000K)
ctx: ██▒░░ 48% | 5h: ░░░░░ 4% 3.1h | 7d: ██░░░ 41% 1.2d
```

## Features

- **Model name** — clean display name (parentheticals stripped)
- **Token usage** — `used/window` in K units, sums input + output + cache creation + cache read
- **Context bar** — 5-cell Unicode bar with partial-fill chars (░▒▓█), green → yellow → orange → red as usage climbs
- **Rate limits** — 5-hour and 7-day usage bars with time-until-reset

## Install

```bash
mkdir -p ~/.claude
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/jqbit/colorbars/main/statusline.sh
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

Restart Claude Code.

## Requirements

- `jq`
- Python 3

## Color thresholds

| Metric | Green | Yellow | Orange | Red |
|--------|-------|--------|--------|-----|
| Context window | < 40% | 40%+ | 60%+ | 80%+ |
| Rate limits | < 50% | 50%+ | 75%+ | 90%+ |

## Test

```bash
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":48,"context_window_size":1000000,"current_usage":{"input_tokens":400000,"output_tokens":40000,"cache_creation_input_tokens":20000,"cache_read_input_tokens":20000}},"rate_limits":{"five_hour":{"used_percentage":4,"resets_at":'$(($(date +%s) + 11160))'},"seven_day":{"used_percentage":41,"resets_at":'$(($(date +%s) + 103680))'}}}' | bash ~/.claude/statusline.sh
```

## License

MIT
