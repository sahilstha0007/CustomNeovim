local wezterm = require('wezterm')
local platform = require('utils.platform')
local backdrops = require('utils.backdrops')
local act = wezterm.action

local mod = {}

if platform.is_mac then
   mod.SUPER = 'SUPER'
   mod.SUPER_REV = 'SUPER|CTRL'
elseif platform.is_win or platform.is_linux then
   mod.SUPER = 'ALT' -- to not conflict with Windows key shortcuts
   mod.SUPER_REV = 'ALT|CTRL'
end

-- Wallpaper picker (Alt+p): full-screen live preview of each wallpaper.
-- Enter commits (remembers + runs the theme cascade), Esc/q reverts to the
-- image you had when the picker opened. Browse keys are in the key table.
local wallpaper_picker_original = nil

local function wallpaper_picker_status(window)
   local img = backdrops.images[backdrops.current_idx]
   local name = img and img:match('([^/]+)$') or '?'
   window:toast_notification(
      string.format('Wallpaper %d/%d', backdrops.current_idx, #backdrops.images),
      name,
      1200
   )
end

local picker_prev = wezterm.action_callback(function(window, _)
   backdrops:preview_step(window, -1)
   wallpaper_picker_status(window)
end)
local picker_next = wezterm.action_callback(function(window, _)
   backdrops:preview_step(window, 1)
   wallpaper_picker_status(window)
end)
local picker_random = wezterm.action_callback(function(window, _)
   backdrops:preview_step(window, 0)
   wallpaper_picker_status(window)
end)
local picker_commit = wezterm.action_callback(function(window, pane)
   backdrops:commit(window)
   window:toast_notification('Wallpaper applied', '', 1200)
   window:perform_action(act.PopKeyTable, pane)
end)
local picker_cancel = wezterm.action_callback(function(window, pane)
   if wallpaper_picker_original ~= nil then
      backdrops:preview_jump(window, wallpaper_picker_original)
   end
   window:perform_action(act.PopKeyTable, pane)
end)

-- stylua: ignore
---@type Key[]
local keys = {
   -- misc/useful --
   { key = 'F1', mods = 'NONE', action = act.ActivateCopyMode },
   { key = 'F2', mods = 'NONE', action = act.ActivateCommandPalette },
   -- F6: symbol/emoji picker — browse glyphs (nerd icons, box drawing,
   -- emoji) from the installed fallback fonts, Enter inserts into the pane.
   { key = 'F6', mods = 'NONE', action = act.CharSelect },
   { key = 'F3', mods = 'NONE', action = act.ShowLauncher },
   { key = 'F4', mods = 'NONE', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },
   {
      key = 'F5',
      mods = 'NONE',
      action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }),
   },
   { key = 'F11', mods = 'NONE',    action = act.ToggleFullScreen },
   { key = 'F12', mods = 'NONE',    action = act.ShowDebugOverlay },
   { key = 'f',   mods = mod.SUPER, action = act.Search({ CaseInSensitiveString = '' }) },
   {
      key = 'u',
      mods = mod.SUPER_REV,
      action = wezterm.action.QuickSelectArgs({
         label = 'open url',
         patterns = {
            '\\((https?://\\S+)\\)',
            '\\[(https?://\\S+)\\]',
            '\\{(https?://\\S+)\\}',
            '<(https?://\\S+)>',
            '\\bhttps?://\\S+[)/a-zA-Z0-9-]+'
         },
         action = wezterm.action_callback(function(window, pane)
            local url = window:get_selection_text_for_pane(pane)
            wezterm.log_info('opening: ' .. url)
            wezterm.open_with(url)
         end),
      }),
   },

   -- cursor movement --
   { key = 'LeftArrow',  mods = mod.SUPER,     action = act.SendString('\u{1b}OH') },
   { key = 'RightArrow', mods = mod.SUPER,     action = act.SendString('\u{1b}OF') },
   { key = 'Backspace',  mods = mod.SUPER,     action = act.SendString('\u{15}') },

   -- copy/paste --
   { key = 'c',          mods = 'CTRL|SHIFT',  action = act.CopyTo('Clipboard') },
   { key = 'v',          mods = 'CTRL|SHIFT',  action = act.PasteFrom('Clipboard') },
   -- generic quick-select: type the shown letter to copy that match
   -- (default pattern set: URLs, git hashes, hex colors, filenames...)
   { key = 'Space',      mods = 'CTRL|SHIFT',  action = act.QuickSelect },

   { key = 'n',          mods = 'CTRL|SHIFT',  action = act.SendString('\u{2660}') },
   { key = 's',          mods = 'CTRL|SHIFT',  action = act.SendString('\u{203D}') },

   -- tabs --
   -- tabs: spawn+close
   { key = 't',          mods = mod.SUPER,     action = act.SpawnTab('DefaultDomain') },
   { key = 't',          mods = mod.SUPER_REV, action = act.SpawnTab({ DomainName = 'wsl:ubuntu-fish' }) },
   { key = 'w',          mods = mod.SUPER_REV, action = act.CloseCurrentTab({ confirm = false }) },

   -- tabs: navigation
   { key = '[',          mods = mod.SUPER,     action = act.ActivateTabRelative(-1) },
   { key = ']',          mods = mod.SUPER,     action = act.ActivateTabRelative(1) },
   { key = '[',          mods = mod.SUPER_REV, action = act.MoveTabRelative(-1) },
   { key = ']',          mods = mod.SUPER_REV, action = act.MoveTabRelative(1) },

   -- tab: title
   { key = '0',          mods = mod.SUPER,     action = act.EmitEvent('tabs.manual-update-tab-title') },
   { key = '0',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.reset-tab-title') },

   -- tab: hide tab-bar
   { key = '9',          mods = mod.SUPER,     action = act.EmitEvent('tabs.toggle-tab-bar'), },

   -- NOTE: no Alt+1..8 tab jumps here on purpose — wezterm would eat the
   -- key before tmux ever sees it, killing tmux's Alt+1..9 window jump
   -- (tmux owns windows/panes; wezterm tabs are the outer chrome, see
   -- the "Double chrome" gotcha in the Obsidian notes).

   -- window --
   -- window: spawn windows
   { key = 'n',          mods = mod.SUPER,     action = act.SpawnWindow },

   -- window: zoom window
   {
      key = '-',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local dimensions = window:get_dimensions()
         -- on Windows 11 (the only OS I'm able to test this on), `is_full_screen` is always false (it's a bug).
         -- Calling `set_inner_size` when the window is actually in fullscreen will cause the
         -- program UI to completely freeze.
         if platform.is_win or dimensions.is_full_screen then
            return
         end
         local new_width = dimensions.pixel_width - 50
         local new_height = dimensions.pixel_height - 50
         window:set_inner_size(new_width, new_height)
      end)
   },
   {
      key = '=',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local dimensions = window:get_dimensions()
         -- on Windows 11 (the only OS I'm able to test this on), `is_full_screen` is always false (it's a bug).
         -- Calling `set_inner_size` when the window is actually in fullscreen will cause the
         -- program UI to completely freeze.
         if platform.is_win or dimensions.is_full_screen then
            return
         end
         local new_width = dimensions.pixel_width + 50
         local new_height = dimensions.pixel_height + 50
         window:set_inner_size(new_width, new_height)
      end)
   },
   {
      key = 'Enter',
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, _pane)
         window:maximize()
      end)
   },

   -- background controls --
   -- Cycle back/forward are bound to BOTH the raw key and its shifted
   -- partner (`,`/`<`, `.`/`>`): on most layouts `<`/`>` are Shift+`,`/`. and
   -- the shift folds into the produced char, so only one form ever matches.
   {
      key = [[/]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:random(window)
      end),
   },
   {
      key = [[,]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_back(window)
      end),
   },
   {
      key = '<',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_back(window)
      end),
   },
   {
      key = [[.]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_forward(window)
      end),
   },
   {
      key = '>',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_forward(window)
      end),
   },
   {
      key = [[/]],
      mods = mod.SUPER_REV,
      -- Built at press time (not load time) so the list is re-globbed and
      -- re-fetched every time the picker opens: drop a new wallpaper into
      -- ~/Pictures/wallpaper and it appears here without a wezterm restart.
      action = wezterm.action_callback(function(window, pane)
         window:perform_action(
            act.InputSelector({
               title = 'InputSelector: Select Background',
               choices = backdrops:rescan():choices(),
               fuzzy = true,
               fuzzy_description = 'Select Background: ',
               action = wezterm.action_callback(function(w, _pane, idx)
                  if not idx then
                     return
                  end
                  ---@diagnostic disable-next-line: param-type-mismatch
                  backdrops:set_img(w, tonumber(idx))
               end),
            }),
            pane
         )
      end),
   },
   {
      key = 'b',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:toggle_focus(window)
      end)
   },

   -- wallpaper picker: full-screen live preview (Enter applies, Esc cancels)
   {
      key = 'p',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, pane)
         if #backdrops.images == 0 then
            return
         end
         wallpaper_picker_original = backdrops.current_idx
         window:toast_notification(
            'Wallpaper picker',
            '← → / h l / , . browse · r random · Enter apply · Esc cancel',
            3000
         )
         window:perform_action(
            act.ActivateKeyTable({
               name = 'wallpaper_picker',
               one_shot = false,
               timeout_milliseconds = 20000,
            }),
            pane
         )
      end),
   },

   -- panes --
   -- panes: split panes
   {
      key = [[\]],
      mods = mod.SUPER,
      action = act.SplitVertical({ domain = 'CurrentPaneDomain' }),
   },
   {
      key = [[\]],
      mods = mod.SUPER_REV,
      action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }),
   },

   -- panes: zoom+close pane
   { key = 'Enter', mods = mod.SUPER,     action = act.TogglePaneZoomState },
   { key = 'w',     mods = mod.SUPER,     action = act.CloseCurrentPane({ confirm = false }) },

   -- NOTE: no Ctrl+Alt+hjkl pane navigation here on purpose — wezterm
   -- would eat the key before tmux ever sees it, killing tmux.nvim's
   -- C-M-hjkl pane-swap binding (tmux owns windows/panes; wezterm is
   -- outer chrome only — see the "Double chrome" gotcha in Obsidian).
   {
      key = 'p',
      mods = mod.SUPER_REV,
      action = act.PaneSelect({ alphabet = '1234567890', mode = 'SwapWithActiveKeepFocus' }),
   },

   -- panes: scroll pane
   -- NOTE: no bare PageUp/PageDown binds — wezterm would eat them before
   -- tmux sees them, killing tmux's `bind -n PageUp copy-mode -u` scrollback
   -- entry. The default (pass through to the app) is what we want.

   -- key-tables --
   -- resizes fonts
   {
      key = 'f',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_font',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
   -- resize panes
   {
      key = 'p',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_pane',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
}

-- stylua: ignore
---@type table<string, Key[]>
local key_tables = {
   wallpaper_picker = {
      { key = 'h',          action = picker_prev },
      { key = 'LeftArrow',  action = picker_prev },
      { key = ',',          action = picker_prev },
      { key = 'l',          action = picker_next },
      { key = 'RightArrow', action = picker_next },
      { key = '.',          action = picker_next },
      { key = 'r',          action = picker_random },
      { key = '/',          action = picker_random },
      { key = 'Enter',      action = picker_commit },
      { key = 'q',          action = picker_cancel },
      { key = 'Escape',     action = picker_cancel },
   },
   resize_font = {
      { key = 'k',      action = act.IncreaseFontSize },
      { key = 'j',      action = act.DecreaseFontSize },
      { key = 'r',      action = act.ResetFontSize },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
   },
   resize_pane = {
      { key = 'k',      action = act.AdjustPaneSize({ 'Up', 1 }) },
      { key = 'j',      action = act.AdjustPaneSize({ 'Down', 1 }) },
      { key = 'h',      action = act.AdjustPaneSize({ 'Left', 1 }) },
      { key = 'l',      action = act.AdjustPaneSize({ 'Right', 1 }) },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
   },
}

---@type MouseBinding[]
local mouse_bindings = {
   -- Ctrl-click will open the link under the mouse cursor
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
   },
}

---@type Config
return {
   disable_default_key_bindings = true,
   -- disable_default_mouse_bindings = true,
   leader = { key = 'Space', mods = mod.SUPER_REV },
   keys = keys,
   key_tables = key_tables,
   mouse_bindings = mouse_bindings,
}
