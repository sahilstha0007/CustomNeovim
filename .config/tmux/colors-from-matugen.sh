#!/usr/bin/env bash
# Derive tmux theme colors from the SAME matugen palette wezterm renders
# (~/.config/wezterm/colors/matugen.lua), so tmux adopts the wallpaper exactly
# like wezterm/nvim — one source of truth, all three in sync.
#
# Like wezterm's colors/custom.lua, the wallpaper's background luminance picks
# the catppuccin base — latte (light theme, dark text) or mocha (dark theme,
# bright text) — and the matugen tokens override the same subset custom.lua
# overrides. Everything else keeps that base's own defaults, so the WHOLE
# status bar flips correctly on light wallpapers. Keep both files in sync.
#
# The file is sourced AFTER the catppuccin theme, so it fully determines the
# visible colors. Both underscore (@thm_surface_0, catppuccin theme naming)
# and underscore-less (@thm_surface0, used by some helper scripts) spellings
# are emitted for the tokens people reference.
#
# Usage: colors-from-matugen.sh [SRC] [OUT]   (defaults below)
# Run manually after a wallpaper change (sync-wallpaper.sh calls it too).
# Takes effect on the next tmux start (or `tmux source-file ~/.config/tmux/tmux.conf`).

set -euo pipefail

src="${1:-$HOME/.config/wezterm/colors/matugen.lua}"
out="${2:-$HOME/.config/tmux/colors-matugen.conf}"

[ -f "$src" ] || exit 0

get() {
  sed -nE "s/^[[:space:]]*$1 = \"#([0-9a-fA-F]{6})\".*/\1/p" "$src" | head -1
}

bg=$(get background)
fg=$(get foreground)

# Luminance decides the base: same rule as colors/custom.lua (0.299/0.587/0.114
# weighting, threshold 0.5). Pure bash so no gawk dependency.
bghex=${bg:-000000}
_r=$((16#${bghex:1:2})); _g=$((16#${bghex:3:2})); _b=$((16#${bghex:5:2}))
if [ $((299 * _r + 587 * _g + 114 * _b)) -ge 127500 ]; then
  is_light=1
else
  is_light=0
fi

# Catppuccin token values for the mode's base (same tables as custom.lua).
if [ "$is_light" = 1 ]; then
  # catppuccin latte
  D_rosewater=dc8a78 D_flamingo=dd7878 D_pink=ea76cb D_mauve=8839ef
  D_red=d20f39 D_maroon=e64553 D_peach=fe640b D_yellow=df8e1d
  D_green=40a02b D_teal=179299 D_sky=04a5e5 D_sapphire=209fb5
  D_blue=1e66f5 D_lavender=7287fd
  D_text=4c4f69 D_subtext_1=5c5f77 D_subtext_0=6c6f85
  D_overlay_2=7c7f93 D_overlay_1=8c8fa1 D_overlay_0=9ca0b0
  D_surface_2=acb0be D_surface_1=bcc0cc D_surface_0=ccd0da
  D_base=eff1f5 D_mantle=e6e9ef D_crust=dce0e8
else
  # catppuccin mocha
  D_rosewater=f5e0dc D_flamingo=f2cdcd D_pink=f5c2e7 D_mauve=cba6f7
  D_red=f38ba8 D_maroon=eba0ac D_peach=fab387 D_yellow=f9e2af
  D_green=a6e3a1 D_teal=94e2d5 D_sky=89dceb D_sapphire=74c7ec
  D_blue=89b4fa D_lavender=b4befe
  D_text=cdd6f4 D_subtext_1=bac2de D_subtext_0=a6adc8
  D_overlay_2=9399b2 D_overlay_1=7f849c D_overlay_0=6c7086
  D_surface_2=585b70 D_surface_1=45475a D_surface_0=313244
  D_base=1e1e2e D_mantle=181825 D_crust=11111b
fi

primary=$(get primary)       # -> blue/rosewater/teal (like custom.lua)
secondary=$(get secondary)   # -> pink
tertiary=$(get tertiary)     # -> yellow
error=$(get error)           # -> red
success=$(get success)       # -> green
surface0=$(get surface0)
surface1=$(get surface1)
surface2=$(get surface2)
outline=$(get outline)       # -> overlay0

# Fall back to the mode defaults for any token matugen did not provide.
primary=${primary:-$D_blue}; secondary=${secondary:-$D_pink}
tertiary=${tertiary:-$D_yellow}; error=${error:-$D_red}; success=${success:-$D_green}
surface0=${surface0:-$D_surface_0}; surface1=${surface1:-$D_surface_1}
surface2=${surface2:-$D_surface_2}; outline=${outline:-$D_overlay_0}
bg=${bg:-$D_base}; fg=${fg:-$D_text}

# --- Readability guard -----------------------------------------------------
# matugen tokens are wallpaper-derived, so a token can be unreadable as status
# text (e.g. "success" came out dark brown #7f560f on this wallpaper and
# painted the session name + date nearly invisible). If a token doesn't
# contrast with the theme background, fall back to the catppuccin base color
# for that slot — same idea as nvim's hue gate in terminal-colors.lua.
lum() { # lum <hex-no-#> -> 0..255000 perceived luminance
  local h="$1"
  echo $((299 * 16#${h:0:2} + 587 * 16#${h:2:2} + 114 * 16#${h:4:2}))
}
guard() { # guard <hex-no-#> <limit> <fallback-hex-no-#>; echoes the value to use
  local h="$1" limit="$2" fb="$3" l
  l=$(lum "$h")
  if [ "$is_light" = 1 ]; then
    # light theme: a token lighter than ~63% luminance vanishes into the paper
    [ "$l" -gt "$limit" ] && echo "$fb" || echo "$h"
  else
    # dark theme: a token darker than ~40% luminance vanishes into the glass
    [ "$l" -lt "$limit" ] && echo "$fb" || echo "$h"
  fi
}

if [ "$is_light" = 1 ]; then
  primary=$(guard "$primary" 160000 "$D_blue")
  secondary=$(guard "$secondary" 160000 "$D_pink")
  tertiary=$(guard "$tertiary" 160000 "$D_yellow")
  error=$(guard "$error" 160000 "$D_red")
  success=$(guard "$success" 160000 "$D_green")
else
  primary=$(guard "$primary" 102000 "$D_blue")
  secondary=$(guard "$secondary" 102000 "$D_pink")
  tertiary=$(guard "$tertiary" 102000 "$D_yellow")
  error=$(guard "$error" 102000 "$D_red")
  success=$(guard "$success" 102000 "$D_green")
fi

emit() { # emit <name> <value>: single set -g line
  printf 'set -g @thm_%s "#%s"\n' "$1" "$2"
}

{
  echo "# Auto-generated from $src by colors-from-matugen.sh — do not edit by hand."
  echo "# $([ "$is_light" = 1 ] && echo 'light theme (wallpaper luminance)' || echo 'dark theme (wallpaper luminance)')"
  echo "set -g @catppuccin_flavor \"$([ "$is_light" = 1 ] && echo latte || echo mocha)\""
  echo
  echo "# Catppuccin base ($([ "$is_light" = 1 ] && echo latte || echo mocha)) — canonical underscore names"
  emit bg "$D_base"
  emit fg "$D_text"
  emit rosewater "$D_rosewater"
  emit flamingo "$D_flamingo"
  emit pink "$D_pink"
  emit mauve "$D_mauve"
  emit red "$D_red"
  emit maroon "$D_maroon"
  emit peach "$D_peach"
  emit yellow "$D_yellow"
  emit green "$D_green"
  emit teal "$D_teal"
  emit sky "$D_sky"
  emit sapphire "$D_sapphire"
  emit blue "$D_blue"
  emit lavender "$D_lavender"
  emit subtext_1 "$D_subtext_1"
  emit subtext_0 "$D_subtext_0"
  emit overlay_2 "$D_overlay_2"
  emit overlay_1 "$D_overlay_1"
  emit overlay_0 "$D_overlay_0"
  emit surface_2 "$D_surface_2"
  emit surface_1 "$D_surface_1"
  emit surface_0 "$D_surface_0"
  emit mantle "$D_mantle"
  emit crust "$D_crust"
  echo
  echo "# Underscore-less aliases (referenced by helper scripts)"
  emit text "$D_text"
  emit base "$D_base"
  emit subtext1 "$D_subtext_1"
  emit subtext0 "$D_subtext_0"
  emit overlay2 "$D_overlay_2"
  emit overlay1 "$D_overlay_1"
  emit overlay0 "$D_overlay_0"
  emit surface2 "$D_surface_2"
  emit surface1 "$D_surface_1"
  emit surface0 "$D_surface_0"
  echo
  echo "# Wallpaper overrides (mirrors wezterm colors/custom.lua)"
  emit bg "$bg"
  emit fg "$fg"
  emit base "$bg"
  emit text "$fg"
  emit rosewater "$primary"
  emit red "$error"
  emit green "$success"
  emit yellow "$tertiary"
  emit blue "$primary"
  emit pink "$secondary"
  emit teal "$primary"
  emit overlay_0 "$outline"
  emit overlay0 "$outline"
  emit surface_0 "$surface0"
  emit surface0 "$surface0"
  emit surface_1 "$surface1"
  emit surface1 "$surface1"
  emit surface_2 "$surface2"
  emit surface2 "$surface2"
  emit mantle "$bg"
  emit crust "$bg"
} > "$out"
