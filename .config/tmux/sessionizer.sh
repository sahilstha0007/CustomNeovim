#!/usr/bin/env bash
# tmux sessionizer — Prefix + f
# fzf over project dirs -> create/switch to a named session rooted there.
# Works from inside tmux (popup) and from a bare shell (attaches).

projects="$HOME/Projects"

# loose projects at ~/Projects/* plus categorized ones under Current/ and Learning/
list=$(
    {
        find "$projects" -mindepth 1 -maxdepth 1 -type d \
            ! -name node_modules ! -name .git \
            ! -path "$projects/Current" ! -path "$projects/Learning"
        find "$projects/Current" "$projects/Learning" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
    } | sort -u
)

selected=$(printf '%s\n' "$list" | fzf --prompt='project ❯ ' --preview='ls -A {} | head -20')

[[ -z $selected ]] && exit 0

# session names can't contain . or :
name=$(basename "$selected" | tr '.:' '__')

if ! tmux has-session -t "$name" 2>/dev/null; then
    tmux new-session -ds "$name" -c "$selected"
fi

if [[ -n $TMUX ]]; then
    tmux switch-client -t "$name"
else
    exec tmux attach -t "$name"
fi
