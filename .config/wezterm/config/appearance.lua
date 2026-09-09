local gpu_adapters = require('utils.gpu-adapter')
local backdrops = require('utils.backdrops')
local colors = require('colors.custom')

---@type Config
return {
   max_fps = 60, -- matches the 1920x1080@60Hz panel exactly (vsync-bound);
   -- a higher cap on a 60Hz panel just over-renders frames the panel drops
   front_end = 'WebGpu', ---@type 'WebGpu' | 'OpenGL' | 'Software'
   -- user preference: use the hardware for smoothness — steady Vega clocks
   -- mean steadier frame pacing (no power-state hitches) on this iGPU-only
   -- laptop. Trade: slightly higher power draw. Flip back to 'LowPower'
   -- on battery if you want the quieter GPU.
   webgpu_power_preference = 'HighPerformance',
   webgpu_preferred_adapter = gpu_adapters:pick_best(),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Dx12', 'IntegratedGpu'),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Gl', 'Other'),
   underline_thickness = '1.5pt',

   -- cursor
   animation_fps = 60, -- panel-bound; easing does the smoothing, not fps
   -- kitty-style blink, but GLIDED: eased on/off (EaseInOut) instead of a
   -- hard toggle — the fade is what reads as smooth. 650ms half-period.
   default_cursor_style = 'BlinkingBlock',
   cursor_blink_rate = 650,
   cursor_blink_ease_in = 'EaseInOut',
   cursor_blink_ease_out = 'EaseInOut',

   -- color scheme
   colors = colors,

   -- pane-select overlay (SUPER+CTRL+p): the number chips reuse the active
   -- tab language — wallpaper-synced accent pill (colorscheme ansi[5], same
   -- token the custom tab bar and tmux pill use). The label follows the
   -- theme: accent is bright on dark wallpapers (dark label) but dark on
   -- light wallpapers (light label = colors.background), so it can never
   -- paint dark-on-dark or light-on-light.
   pane_select_fg_color = colors.background,
   pane_select_bg_color = colors.ansi[5],

   -- background: pass in `true` if you want wezterm to start with focus mode on (no bg images)
   background = backdrops:initial_options({ no_img = false, }),

   -- scrollbar
   enable_scroll_bar = true,

   -- tab bar
   enable_tab_bar = true,
   -- Single-chrome rule: tmux owns windows inside a session, so the common
   -- case (one wezterm tab running tmux) hides the wezterm bar — no stacked
   -- tab strips. The bar (titles, progress, unseen, new-tab button) returns
   -- the moment a second wezterm tab is opened. Want NO bar ever inside
   -- tmux? Set enable_tab_bar = false instead.
   hide_tab_bar_if_only_one_tab = true,
   use_fancy_tab_bar = false,
   tab_max_width = 23,
   show_tab_index_in_tab_bar = false,
   switch_to_last_active_tab_when_closing_tab = true,

   -- command palette — adopts the colorscheme (wallpaper-synced) instead of
   -- pinned mocha hexes
   command_palette_fg_color = colors.foreground,
   command_palette_bg_color = colors.background,
   command_palette_font_size = 12,
   command_palette_rows = 25,

   -- window
   window_padding = {
      left = 0,
      right = 0,
      top = 10,
      bottom = 7.5,
   },
   adjust_window_size_when_changing_font_size = false,
   window_close_confirmation = 'NeverPrompt',
   -- FULL TRANSPARENCY (user preference): the window itself renders at 85%
   -- opacity so the DESKTOP wallpaper (Hyprland) shows through everywhere —
   -- editor, panes, chrome. The in-app background layers (backdrops.lua)
   -- carry only a light tint; this option is what punches the real hole in
   -- the window. Raise toward 1.0 if text ever feels washed out.
   window_background_opacity = 0.85,
   -- dim inactive panes so the focused pane pops (sharper focus than the
   -- 0.8 glassy pass, but not as muddy as the original 0.72)
   inactive_pane_hsb = {
      saturation = 0.88,
      brightness = 0.74,
   },

   visual_bell = {
      fade_in_function = 'EaseIn',
      fade_in_duration_ms = 250,
      fade_out_function = 'EaseOut',
      fade_out_duration_ms = 250,
      target = 'CursorColor',
   },
}
