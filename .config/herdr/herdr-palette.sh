#!/usr/bin/env bash
# Re-theme herdr's chrome from the SAME matugen palette wezterm renders
# (~/.config/wezterm/colors/matugen.lua), so herdr adopts the wallpaper
# exactly like tmux/nvim/oh-my-posh — one source of truth.
#
# Like colors-from-matugen.sh, the wallpaper's background luminance picks the
# catppuccin base (latte = light theme/dark text, mocha = dark theme/bright
# text) and the matugen tokens override the same subset that file overrides.
# 0.7.5 does not know sidebar_bg/active_row_bg/selection_bg (too new), so the
# sidebar follows surface0/panel_bg and this list sticks to accepted tokens:
#
#   herdr token   <- shared role (same assignment as tmux @thm_* overrides)
#   accent        <- wallpaper primary   (tmux: blue/rosewater/teal <- primary)
#   text          <- wallpaper foreground
#   panel_bg      <- wallpaper background (tmux: bg/base/mantle/crust)
#   surface_dim   <- wallpaper background (deepest panel layer)
#   surface0      <- wallpaper surface0
#   surface1      <- wallpaper surface1
#   overlay0      <- wallpaper outline    (tmux: overlay_0 <- outline)
#   overlay1      <- catppuccin base overlay_1 (tmux leaves overlay_1 stock)
#   subtext0      <- catppuccin base subtext_0 (tmux leaves subtext stock)
#   mauve         <- wallpaper secondary  (tmux: pink <- secondary)
#   blue/teal     <- wallpaper primary
#   yellow        <- wallpaper tertiary
#   red           <- wallpaper error
#   green         <- wallpaper success
#   peach         <- catppuccin base peach (no wallpaper equivalent)
#
# Usage: herdr-palette.sh [SRC] [TEMPLATE] [OUT]   (defaults below)
# Run manually after a wallpaper change (sync-wallpaper.sh calls it too).
# Takes effect on `herdr server reload-config` (or prefix+shift+r inside herdr).

set -euo pipefail

src="${1:-$HOME/.config/wezterm/colors/matugen.lua}"
tpl="${2:-$HOME/.config/herdr/config.template.toml}"
out="${3:-$HOME/.config/herdr/config.toml}"

[ -f "$src" ] || exit 0
[ -f "$tpl" ] || exit 0

get() {
  sed -nE "s/^[[:space:]]*$1 = \"#([0-9a-fA-F]{6})\".*/\1/p" "$src" | head -1
}

bg=$(get background)
fg=$(get foreground)

# Luminance decides the base: same rule as colors/custom.lua and
# colors-from-matugen.sh (0.299/0.587/0.114 weighting, threshold 0.5).
bghex=${bg:-000000}
_r=$((16#${bghex:0:2})); _g=$((16#${bghex:2:2})); _b=$((16#${bghex:4:2}))
if [ $((299 * _r + 587 * _g + 114 * _b)) -ge 127500 ]; then
  is_light=1
else
  is_light=0
fi

# Catppuccin token values for the mode's base (same tables as
# colors-from-matugen.sh — keep both in sync).
if [ "$is_light" = 1 ]; then
  # catppuccin latte
  D_mauve=8839ef D_red=d20f39 D_peach=fe640b D_yellow=df8e1d
  D_green=40a02b D_teal=179299 D_blue=1e66f5
  D_text=4c4f69 D_subtext_0=6c6f85 D_overlay_1=8c8fa1
  D_surface_0=ccd0da D_surface_1=bcc0cc D_surface_2=acb0be
else
  # catppuccin mocha
  D_mauve=cba6f7 D_red=f38ba8 D_peach=fab387 D_yellow=f9e2af
  D_green=a6e3a1 D_teal=94e2d5 D_blue=89b4fa
  D_text=cdd6f4 D_subtext_0=a6adc8 D_overlay_1=7f849c
  D_surface_0=313244 D_surface_1=45475a D_surface_2=585b70
fi

# Matugen roles, falling back to the mode's own defaults when the palette
# does not provide a token (mirrors colors-from-matugen.sh).
primary=$(get primary);      primary=${primary:-$D_blue}
secondary=$(get secondary);  secondary=${secondary:-$D_mauve}
tertiary=$(get tertiary);    tertiary=${tertiary:-$D_yellow}
error=$(get error);          error=${error:-$D_red}
success=$(get success);      success=${success:-$D_green}
surface0=$(get surface0);    surface0=${surface0:-$D_surface_0}
surface1=$(get surface1);    surface1=${surface1:-$D_surface_1}
surface2=$(get surface2);    surface2=${surface2:-$D_surface_2}
outline=$(get outline);      outline=${outline:-$D_overlay_1}
bg=${bg:-$D_text}; fg=${fg:-$D_text}

sed -e "s|@@ACCENT@@|#$primary|g" \
    -e "s|@@PANEL_BG@@|#$bg|g" \
    -e "s|@@SURFACE0@@|#$surface0|g" \
    -e "s|@@SURFACE1@@|#$surface1|g" \
    -e "s|@@SURFACE_DIM@@|#$bg|g" \
    -e "s|@@OVERLAY0@@|#$outline|g" \
    -e "s|@@OVERLAY1@@|#$D_overlay_1|g" \
    -e "s|@@TEXT@@|#$fg|g" \
    -e "s|@@SUBTEXT0@@|#$D_subtext_0|g" \
    -e "s|@@MAUVE@@|#$secondary|g" \
    -e "s|@@GREEN@@|#$success|g" \
    -e "s|@@YELLOW@@|#$tertiary|g" \
    -e "s|@@RED@@|#$error|g" \
    -e "s|@@BLUE@@|#$primary|g" \
    -e "s|@@TEAL@@|#$primary|g" \
    -e "s|@@PEACH@@|#$D_peach|g" \
    "$tpl" > "$out"
exit 0
