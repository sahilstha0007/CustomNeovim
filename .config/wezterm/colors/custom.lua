-- Wallpaper-driven colorscheme: matugen tokens (colors/matugen.lua, written by
-- utils/sync-wallpaper.sh with `-m smart`) are merged onto a catppuccin base.
-- The base — mocha (dark) or latte (light) — is chosen from the wallpaper's
-- own background luminance, so a bright wallpaper yields a LIGHT theme (dark
-- text, dark accents readable on light) and a dark wallpaper a DARK theme
-- (bright text). Everything downstream (nvim via OSC/file adoption, tmux via
-- colors-from-matugen.sh) derives light/dark the same way, so all three stay
-- in sync from this one file.
-- stylua: ignore

local function luminance(hex)
   local r = tonumber(hex:sub(2, 3), 16) or 0
   local g = tonumber(hex:sub(4, 5), 16) or 0
   local b = tonumber(hex:sub(6, 7), 16) or 0
   return (0.299 * r + 0.587 * g + 0.114 * b) / 255
end

-- Catppuccin mocha (dark wallpaper base)
local mocha = {
   rosewater = '#f5e0dc',
   flamingo  = '#f2cdcd',
   pink      = '#f5c2e7',
   mauve     = '#cba6f7',
   red       = '#f38ba8',
   maroon    = '#eba0ac',
   peach     = '#fab387',
   yellow    = '#f9e2af',
   green     = '#a6e3a1',
   teal      = '#94e2d5',
   sky       = '#89dceb',
   sapphire  = '#74c7ec',
   blue      = '#89b4fa',
   lavender  = '#b4befe',
   text      = '#cdd6f4',
   subtext1  = '#bac2de',
   subtext0  = '#a6adc8',
   overlay2  = '#9399b2',
   overlay1  = '#7f849c',
   overlay0  = '#6c7086',
   surface2  = '#585b70',
   surface1  = '#45475a',
   surface0  = '#313244',
   base      = '#1f1f28',
   mantle    = '#181825',
   crust     = '#11111b',
}

-- Catppuccin latte (light wallpaper base)
local latte = {
   rosewater = '#dc8a78',
   flamingo  = '#dd7878',
   pink      = '#ea76cb',
   mauve     = '#8839ef',
   red       = '#d20f39',
   maroon    = '#e64553',
   peach     = '#fe640b',
   yellow    = '#df8e1d',
   green     = '#40a02b',
   teal      = '#179299',
   sky       = '#04a5e5',
   sapphire  = '#209fb5',
   blue      = '#1e66f5',
   lavender  = '#7287fd',
   text      = '#4c4f69',
   subtext1  = '#5c5f77',
   subtext0  = '#6c6f85',
   overlay2  = '#7c7f93',
   overlay1  = '#8c8fa1',
   overlay0  = '#9ca0b0',
   surface2  = '#acb0be',
   surface1  = '#bcc0cc',
   surface0  = '#ccd0da',
   base      = '#eff1f5',
   mantle    = '#e6e9ef',
   crust     = '#dce0e8',
}

-- Readability guard — same rule as tmux's colors-from-matugen.sh (its
-- guard() uses limits 102000/160000 on a 0..255000 luminance scale, i.e.
-- 0.40 / 0.63 here). Wallpaper tokens can land below readable contrast on
-- the theme background: this wallpaper's "success" token is a dark olive
-- that vanished into the near-black bg and made code green unreadable in
-- every CLI tool. A token failing the luminance gate falls back to the
-- catppuccin base color for that slot. Keep in sync with colors-from-matugen.sh.
local function guard(hex, fallback, light)
   if not hex then
      return fallback
   end
   local l = luminance(hex)
   if light then
      if l > 160 / 255 then -- lighter than ~63% vanishes into the paper
         return fallback
      end
   elseif l < 102 / 255 then -- darker than ~40% vanishes into the glass
      return fallback
   end
   return hex
end

-- Apply the wallpaper's matugen tokens over the chosen catppuccin base.
-- Mirrored by ~/.config/tmux/colors-from-matugen.sh — keep in sync.
local function apply_wallpaper(base, mat, light)
   local c = {}
   for k, v in pairs(base) do
      c[k] = v
   end
   c.text      = mat.foreground
   c.base      = mat.background
   c.mantle    = mat.background
   c.crust     = mat.background
   c.red       = guard(mat.error, base.red, light)
   c.green     = guard(mat.success, base.green, light)
   c.yellow    = guard(mat.tertiary, base.yellow, light)
   c.blue      = guard(mat.primary, base.blue, light)
   c.pink      = guard(mat.secondary, base.pink, light)
   c.teal      = guard(mat.primary, base.teal, light)
   c.rosewater = guard(mat.primary, base.rosewater, light)
   c.surface0  = mat.surface0
   c.surface1  = mat.surface1
   c.surface2  = mat.surface2
   c.overlay0  = mat.outline
   return c
end

local base = mocha -- fallback: stock catppuccin mocha if matugen never ran
local ok, matugen = pcall(dofile, os.getenv('HOME') .. '/.config/wezterm/colors/matugen.lua')
if ok and type(matugen) == 'table' and matugen.background then
   -- Bright wallpaper background -> light theme (latte), dark -> mocha.
   local light = luminance(matugen.background) >= 0.5
   base = apply_wallpaper(light and latte or mocha, matugen, light)
end

-- '#rrggbb' -> 'rgba(r, g, b, a)' (alpha 0..1). Used for translucent chrome
-- that must follow the theme: dark glass over dark themes, light glass over
-- light themes.
local function rgba(hex, a)
   local r = tonumber(hex:sub(2, 3), 16) or 0
   local g = tonumber(hex:sub(4, 5), 16) or 0
   local b = tonumber(hex:sub(6, 7), 16) or 0
   return string.format('rgba(%d, %d, %d, %s)', r, g, b, tostring(a))
end

local colorscheme = {
   foreground = base.text,
   background = base.base,
   cursor_bg = base.rosewater,
   cursor_border = base.rosewater,
   cursor_fg = base.crust,
   selection_bg = base.surface2,
   selection_fg = base.text,
   -- quick_select_* need `ColorSpec` tables on this wezterm version
   quick_select_label_bg = { Color = base.surface1 },
   quick_select_label_fg = { Color = base.text },
   quick_select_match_bg = { Color = base.yellow },
   quick_select_match_fg = { Color = base.crust },
   ansi = {
      base.surface1, -- black
      base.red,      -- red
      base.green,    -- green
      base.yellow,   -- yellow
      base.blue,     -- blue
      base.pink,     -- magenta
      base.teal,     -- cyan
      base.subtext1, -- white
   },
   brights = {
      base.surface2, -- black
      base.maroon,   -- red
      base.green,    -- green
      base.yellow,   -- yellow
      base.blue,     -- blue
      base.pink,     -- magenta
      base.teal,     -- cyan
      base.text,     -- white
   },
   tab_bar = {
      background = rgba(base.base, 0.4),
      active_tab = {
         bg_color = base.surface2,
         fg_color = base.text,
      },
      inactive_tab = {
         bg_color = base.surface0,
         fg_color = base.subtext1,
      },
      inactive_tab_hover = {
         bg_color = base.surface0,
         fg_color = base.text,
      },
      new_tab = {
         bg_color = base.base,
         fg_color = base.text,
      },
      new_tab_hover = {
         bg_color = base.mantle,
         fg_color = base.text,
         italic = true,
      },
   },
   visual_bell = base.red,
   indexed = {
      [16] = base.peach,
      [17] = base.rosewater,
   },
   scrollbar_thumb = base.surface2,
   split = base.overlay0,
   compose_cursor = base.flamingo,
}

return colorscheme
