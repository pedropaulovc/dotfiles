#!/usr/bin/env bash
# ~/.config/ccstatusline/git-ahead-behind.sh
input=$(cat)
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
[[ -n $dir ]] && cd "$dir" 2>/dev/null

base=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || base=origin/HEAD
counts=$(git rev-list --left-right --count "HEAD...$base" 2>/dev/null) \
  || { printf 'custom worktree'; exit 0; }

read -r ahead behind <<<"$counts"
printf '%s↓ %s↑' "$behind" "$ahead"