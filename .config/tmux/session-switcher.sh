#!/usr/bin/env bash
# Session switcher — fzf over ALL tmux sessions (attached or not).
# Switches client if inside tmux; attaches otherwise.
set -u

selected=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | fzf --prompt='session ❯ ' --reverse --height=40%)

[[ -z $selected ]] && exit 0

if [[ -n $TMUX ]]; then
    # switch-client errors if the target is the current session; tolerate it
    current=$(tmux display-message -p '#{session_name}')
    [[ $selected == "$current" ]] || tmux switch-client -t "$selected"
else
    exec tmux attach -t "$selected"
fi
