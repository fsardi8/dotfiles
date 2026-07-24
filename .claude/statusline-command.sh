#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

host=$(hostname -s)

left=$(printf '\033[01;32m%s\033[00m:\033[01;34m%s\033[00m' "$host" "$cwd")

parts=""
[ -n "$ctx" ] && parts="ctx:$(printf '%.0f' "$ctx")%"
[ -n "$five_h" ] && parts="${parts:+$parts,}5h:$(printf '%.0f' "$five_h")%"
[ -n "$week" ] && parts="${parts:+$parts,}7d:$(printf '%.0f' "$week")%"
[ -n "$cost" ] && parts="${parts:+$parts,}\$$(printf '%.2f' "$cost")"

printf '%s %s (%s)\n' "$left" "$model" "$parts"
