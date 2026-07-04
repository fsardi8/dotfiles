#!/usr/bin/env bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

user=$(whoami)
host=$(hostname -s)

left=$(printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' "$user" "$host" "$cwd")

right="[$model"
if [ -n "$used" ]; then
  right="$right | ctx: $(printf '%.0f' "$used")%"
fi
right="$right]"

printf '%s  %s\n' "$left" "$right"
