#!/bin/sh
# Sync the current wezterm wallpaper -> wezterm colors ONLY.
# Uses an isolated matugen config so ml4w/hyprland themes are never touched.
#
# `-m smart` lets matugen read the wallpaper's luminance: bright wallpaper ->
# light scheme (dark text), dark wallpaper -> dark scheme (bright text). The
# palette direction lands in colors/matugen.lua and every consumer (wezterm
# custom.lua, tmux colors-from-matugen.sh, nvim terminal-colors.lua) derives
# light/dark from that one file, so the whole stack flips together.
#
# Latency model — wezterm fires this via background_child_process, so a
# keypress never waits on it. Each invocation is short-lived and serialized
# by flock. The quiet-window sleep after acquiring the lock lets rapid
# Alt+</>/+ presses overwrite $target first, so a burst of N presses costs
# ONE matugen run on the FINAL image instead of N queued cascades:
#   * repeat press (image already applied) -> exits in ~1ms
#   * presses during an active sync just update $target; the run holding the
#     lock re-reads it after the quiet window and applies the newest image
img="$1"
[ -n "$img" ] && [ -f "$img" ] || exit 0

cache="$HOME/.cache/wezterm-wallpaper"          # image wezterm restored / shows
target="$HOME/.cache/wezterm-wallpaper.target"  # most recently requested image
synced="$HOME/.cache/wezterm-wallpaper.synced"  # image the last sync applied
lock="$HOME/.cache/wezterm-wallpaper.lock"

# Record the request up-front so whichever run holds the lock converges here.
printf '%s' "$img" > "$target"

# Repeat press (or a wezterm reload re-requesting the current image)?
# Instant no-op — nothing to do, no matugen, no lock.
[ "$img" = "$(cat "$synced" 2>/dev/null)" ] && exit 0

# Serialize. A second press while a sync runs blocks here briefly, then sees
# the target already applied (below) and exits without doing any work.
exec 9>"$lock"
flock -x 9 || exit 0

# Quick check before the quiet window: an earlier run may already have synced
# the latest target while we were waiting for the lock.
t=$(cat "$target" 2>/dev/null) || exit 0
[ "$t" = "$(cat "$synced" 2>/dev/null)" ] && exit 0

# Quiet window: let a burst of presses land and update $target, so only the
# final image of the burst gets themed.
sleep 0.3
t=$(cat "$target" 2>/dev/null) || exit 0
[ "$t" = "$(cat "$synced" 2>/dev/null)" ] && exit 0

# Some wallpapers are PNG data with a .jpg extension (bytes 0x8950 = PNG
# magic). matugen's `-m smart` light/dark detection fails to decode those and
# silently falls back to defaults, so a bright mislabeled image could never
# flip the theme to light. Give matugen a temp copy with the REAL extension.
work="$t"
case "$t" in
   *.png|*.PNG) ;;
   *)
      sig=$(head -c 8 "$t" 2>/dev/null | od -An -tx1 | tr -d ' \n')
      if [ "$sig" = "89504e470d0a1a0a" ]; then
         work="$HOME/.cache/wezterm-wallpaper-work.png"
         cp "$t" "$work"
      fi
      ;;
esac

wez_palette="$HOME/.config/wezterm/colors/matugen.lua"
tmux_palette="$HOME/.config/tmux/colors-matugen.conf"
pre_wez=$(cksum < "$wez_palette" 2>/dev/null)
pre_tmux=$(cksum < "$tmux_palette" 2>/dev/null)

/usr/bin/matugen -c "$HOME/.config/matugen/wezterm.toml" image "$work" --source-color-index 0 -m smart

# Only mark the image as synced AFTER matugen succeeded, so a failed run is
# retried on the next boot instead of being recorded as done with a stale
# palette. $cache is what wezterm restores on start, so keep them together.
printf '%s' "$t" > "$synced"
printf '%s' "$t" > "$cache"

# Re-derive tmux status colors from the same palette (keeps tmux text in
# lockstep with wezterm/nvim instead of a stale hand-written file).
"$HOME/.config/tmux/colors-from-matugen.sh"

# Re-render the oh-my-posh prompt from the same palette as explicit hexes
# (named ANSI colors would go stale inside tmux, whose palette is frozen at
# attach time). oh-my-posh re-reads the file on every prompt, so the next
# prompt shows the new colors with no restart.
"$HOME/.config/ohmyposh/omp-palette.sh"

# Emit zsh highlight colors computed from the wallpaper (nonexistent
# commands render in the accent's complementary hue). New shells pick this
# up; styles are read live by zsh-syntax-highlighting.
"$HOME/.config/wezterm/utils/zsh-highlight-sync.sh"

# Re-render herdr's chrome from the same palette (config.toml is generated
# from config.template.toml by herdr-palette.sh).
"$HOME/.config/herdr/herdr-palette.sh"

# Palette byte-identical (two images mapping to the same colors)? Skip the
# reload cascade — no tmux redraw, no wezterm config reload.
[ "$pre_wez" = "$(cksum < "$wez_palette" 2>/dev/null)" ] \
   && [ "$pre_tmux" = "$(cksum < "$tmux_palette" 2>/dev/null)" ] && exit 0

# Live cascade: tmux status + @thm_* tokens, then touch wezterm.lua so the
# config watcher reloads with the fresh palette (backdrops restores the
# current wallpaper from $cache, so the reload does not reshuffle). herdr
# re-reads its generated config.toml too (silently skipped when not running).
tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
herdr server reload-config >/dev/null 2>&1 || true
touch "$HOME/.config/wezterm/wezterm.lua"
exit 0
