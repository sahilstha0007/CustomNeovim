local wezterm = require('wezterm')
local colors = require('colors.custom')

-- Seeding random numbers before generating for use
-- Known issue with lua math library
-- see: https://stackoverflow.com/questions/20154991/generating-uniform-random-numbers-in-lua
math.randomseed(os.time())
math.random()
math.random()
math.random()

local GLOB_PATTERN = '*.{jpg,jpeg,png,gif,bmp,ico,tiff,pnm,dds,tga}'
local WALLPAPER_CACHE = wezterm.home_dir .. '/.cache/wezterm-wallpaper'
-- Downscaled DISPLAY copies (built by utils/cache-wallpapers.sh): wezterm
-- renders these instead of the full-size originals so wallpaper swaps and
-- startup decode in milliseconds. Theming (matugen) always uses originals.
local DISPLAY_CACHE_DIR = wezterm.home_dir .. '/.cache/wezterm-wallpapers'

---The display copy of an image, or the original while the cache is cold.
---@param img string
---@return string
local function display_path(img)
   local name = img:match('([^/\\\\]+)$')
   local stem = name and name:match('^(.*)%.%w+$') or name
   if not stem then
      return img
   end
   local dst = DISPLAY_CACHE_DIR .. '/' .. stem .. '.jpg'
   local f = io.open(dst, 'r')
   if f then
      f:close()
      return dst
   end
   return img
end

-- '#rrggbb' -> 'rgba(r, g, b, a)' so translucent chrome can follow the theme
-- (dark glass on dark wallpapers, light glass on light ones).
local function rgba(hex, a)
   local r = tonumber(hex:sub(2, 3), 16) or 0
   local g = tonumber(hex:sub(4, 5), 16) or 0
   local b = tonumber(hex:sub(6, 7), 16) or 0
   return string.format('rgba(%d, %d, %d, %s)', r, g, b, tostring(a))
end

-- Last wallpaper sync-wallpaper.sh applied (written before each palette
-- regeneration). Lets a config reload restore the current backdrop instead
-- of reshuffling to a random one — required for live palette reloads.
---@return string|nil absolute path of the cached wallpaper
local function cached_wallpaper()
   local f = io.open(WALLPAPER_CACHE, 'r')
   if not f then
      return nil
   end
   local path = f:read('*l')
   f:close()
   return path
end

---@class BackDrops
---@field current_idx number index of current image
---@field images string[] background images
---@field images_dir string directory of background images. Default is `wezterm.config_dir .. '/backdrops/'`
---@field no_img boolean focus mode on or off
local BackDrops = {}
BackDrops.__index = BackDrops

--- Initialise backdrop controller
---@private
function BackDrops:init()
   local backdrops = {
      current_idx = 1,
      images = {},
      images_dir = wezterm.config_dir .. '/backdrops/',
      no_bg = false,
   }
   return setmetatable(backdrops, self)
end

---Override the default `images_dir`
---Default `images_dir` is `wezterm.config_dir .. '/backdrops/'`
---
--- INFO:
---  This function must be invoked before `scan_images_dir()`
---
---@param path string directory of background images
function BackDrops:set_images_dir(path)
   self.images_dir = path
   if not path:match('/$') then
      self.images_dir = path .. '/'
   end
   return self
end

---**MUST BE RUN BEFORE ALL OTHER `BackDrops` methods**
---Sets the `images` after instantiating `BackDrops`.
---
--- INFO:
---   During the initial load of the config, this function can only invoked in `wezterm.lua`.
---   WezTerm's fs utility `glob` (used in this function) works by running on a spawned child process.
---   This throws a coroutine error if the function is invoked in outside of `wezterm.lua` in the -
---   initial load of the Terminal config.
function BackDrops:scan_images_dir()
   self.images = wezterm.glob(self.images_dir .. GLOB_PATTERN)
   return self
end

---Filter out files from the loaded `images`.
---Must be invoked after `scan_images_dir()`.
---Filenames may be given with or without the file extension.
---@param files string[] list of filenames to exclude
function BackDrops:exclude_files(files)
   -- Stored (not just applied once) so runtime rescans can re-apply them.
   self.excluded = self.excluded or {}
   for _, file in ipairs(files) do
      local name = file:match('([^/\\]+)$') or file
      self.excluded[name] = true
      local stem = name:match('^(.*)%.%w+$')
      if stem then
         self.excluded[stem] = true
      end
   end
   return self:_apply_excludes()
end

---Filter `self.images` against the stored exclusions (from `exclude_files`)
---@private
function BackDrops:_apply_excludes()
   local excluded = self.excluded or {}
   local filtered = {}
   for _, image in ipairs(self.images) do
      local name = image:match('([^/\\]+)$') or image
      local stem = name:match('^(.*)%.%w+$') or name
      if not excluded[name] and not excluded[stem] then
         table.insert(filtered, image)
      end
   end
   self.images = filtered
   return self
end

---Re-glob the images dir at runtime so newly dropped wallpapers are picked up
---without a config reload, keeping the current image selected by path.
---Exclusions from `exclude_files` are re-applied.
---@param window Window? if given, re-applies the (possibly changed) backdrop
function BackDrops:rescan(window)
   local current = self.images[self.current_idx]
   self:scan_images_dir()
   if self.excluded and next(self.excluded) then
      self:_apply_excludes()
   end

   local found = false
   if current and #self.images > 0 then
      for idx, img in ipairs(self.images) do
         if img == current then
            self.current_idx = idx
            found = true
            break
         end
      end
   end
   if not found then
      self.current_idx = #self.images > 0 and math.random(#self.images) or 1
   end

   -- Newly added wallpapers have no display copy yet: warm the cache in the
   -- background so the next preview/cycle is instant.
   self:ensure_display_cache()

   if window ~= nil then
      self:_set_opt(window, self:_gen_opts())
   end
   return self
end

---Kick off background generation of the downscaled display copies (skips
---files already cached; the helper script checks mtimes). Safe to call on
---every cycle — it no-ops once the cache is warm.
---@return boolean true if a cache job was spawned
function BackDrops:ensure_display_cache()
   if #self.images == 0 then
      return false
   end
   local missing = false
   for _, img in ipairs(self.images) do
      if display_path(img) == img then
         missing = true
         break
      end
   end
   if not missing then
      return false
   end
   local args = { wezterm.home_dir .. '/.config/wezterm/utils/cache-wallpapers.sh' }
   for _, img in ipairs(self.images) do
      table.insert(args, img)
   end
   local ok = pcall(wezterm.background_child_process, args)
   if not ok then
      wezterm.run_child_process(args)
   end
   return ok
end

---Create the `background` options with the current image
---@private
---@return BackgroundLayer[]
function BackDrops:_gen_opts()
   local bg_opts = {}

   if #self.images > 0 then
      -- wallpaper — the GLASS itself: kept bright enough to read as a
      -- wallpaper feature through every translucent surface (nvim editor,
      -- shell panes, tmux status, pickers). Bump `brightness` up if text
      -- feels lost on busy images.
      table.insert(bg_opts, {
         -- display copy when cached (fast decode); original while warming
         source = { File = display_path(self.images[self.current_idx]) },
         horizontal_align = 'Center',
         hsb = { brightness = 0.93, saturation = 1.0 },
      })
      -- flat frost wash — the single knob that decides how much "glass"
      -- vs. flat dark you get. 0.8 buries the wallpaper (everything reads
      -- near-opaque); 0.5 is all-glass but soft for code; 0.62 let a busy
      -- wallpaper bleed through ~38% behind every character, which read as
      -- dim text. 0.72 keeps the wallpaper clearly glowing through while
      -- text sits on real glass.
      table.insert(bg_opts, {
         source = { Color = colors.background },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = 0.72,
      })
      -- soft bottom-up fade for depth + tab/status bar legibility. Ends in
      -- TRANSPARENT of the theme background (not a fixed dark), so the chrome
      -- strip stays readable on both dark and light themes.
      table.insert(bg_opts, {
         source = {
            Gradient = {
               colors = { colors.background, rgba(colors.background, 0) },
               orientation = { Linear = { angle = 90 } },
            },
         },
         height = '55%',
         vertical_align = 'Bottom',
         opacity = 0.75,
      })
   else
      table.insert(bg_opts, {
         source = { Color = colors.background },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = 1,
      })
   end

   return bg_opts
end

---Create the `background` options for focus mode
---@private
---@return BackgroundLayer[]
function BackDrops:_gen_no_img_opts()
   return {
      {
         source = { Color = colors.background },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = 1,
      },
   }
end

---Set the initial options for `background`
---@param opts {no_img?: boolean} initial options for `background`
function BackDrops:initial_options(opts)
   opts.no_img = opts.no_img or false
   assert(type(opts.no_img) == 'boolean', 'BackDrops:initial_options - Expected a boolean')

   self.no_img = opts.no_img
   if opts.no_img then
      return self:_gen_no_img_opts()
   end

   return self:_gen_opts()
end

---Override the current window options for background
---@private
---@param window Window WezTerm Window see: https://wezfurlong.org/wezterm/config/lua/window/index.html
---@param background_opts BackgroundLayer[] background option
---Persist the currently chosen wallpaper to the cache file IMMEDIATELY
---(synchronously, before any async theme work finishes). A restart then
---restores exactly what was on screen — even if wezterm quit before the
---background theme worker ran. Without this, closing wezterm right after a
---cycle left the cache pointing at the OLD image and the next start fell
---back to a random wallpaper.
---@private
function BackDrops:_remember()
   local img = self.images[self.current_idx]
   if not img then
      return self
   end
   local f = io.open(WALLPAPER_CACHE, 'w')
   if f then
      f:write(img)
      f:close()
   end
   return self
end

function BackDrops:_set_opt(window, background_opts)
   self:_remember()
   self:_apply(window, background_opts)
end

---Apply background layers to a window WITHOUT remembering the choice or
---syncing the theme — used by the wallpaper preview picker, so browsing is
---instant and side-effect-free. Only `commit`/normal cycling remember + sync.
---@private
function BackDrops:_apply(window, background_opts)
   window:set_config_overrides({
      background = background_opts,
      enable_tab_bar = window:effective_config().enable_tab_bar,
   })
end

---Convert the `images` array to a table of `InputSelector` choices
---see: https://wezfurlong.org/wezterm/config/lua/keyassignment/InputSelector.html
function BackDrops:choices()
   local choices = {}
   for idx, file in ipairs(self.images) do
      table.insert(choices, {
         id = tostring(idx),
         label = file:match('([^/]+)$'),
      })
   end
   return choices
end

---Sync the current background to the rest of the environment
---(matugen themes + hyprpaper desktop); the script debounces repeats
function BackDrops:sync()
   local img = self.images[self.current_idx]
   if img ~= nil then
      local args = {
         wezterm.home_dir .. '/.config/wezterm/utils/sync-wallpaper.sh',
         img,
      }
      -- Fire-and-forget: the keypress handler returns the moment the script
      -- is spawned (script itself is instant for repeats, and does the
      -- matugen + reload cascade in its own serialized run). Falls back to
      -- the synchronous spawn where background spawns aren't allowed yet
      -- (e.g. while the config file is being evaluated at startup/reload).
      local ok = pcall(wezterm.background_child_process, args)
      if not ok then
         wezterm.run_child_process(args)
      end
   end
   return self
end

---Select the cached (last-synced) background if it still exists in the
---images dir, otherwise a random one. Deterministic across config reloads:
---sync-wallpaper.sh touches wezterm.lua to reload the palette live, and this
---keeps that reload from reshuffling the user's chosen wallpaper.
---Pass in `Window` object to override the current window options
---@param window Window? WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:from_cache_or_random(window)
   local cached = cached_wallpaper()
   local found = false
   if cached and #self.images > 0 then
      for idx, img in ipairs(self.images) do
         if img == cached then
            self.current_idx = idx
            found = true
            break
         end
      end
   end
   if not found then
      -- First boot (no cache) or the cached file vanished: pick one and
      -- persist it now so the NEXT start is stable, never random again.
      self.current_idx = math.random(#self.images)
      self:_remember()
   end

   if window ~= nil then
      self:_set_opt(window, self:_gen_opts())
   end
   -- No theme sync here: spawning processes while the config file is being
   -- evaluated is unreliable. events/gui-startup.lua runs the palette
   -- cascade after the first window exists if the shown wallpaper has not
   -- been synced yet, so text colors always follow the displayed image.
   return self
end

---Select a random background from the loaded `files`
---Pass in `Window` object to override the current window options
---@param window Window? WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:random(window)
   self:rescan()
   self.current_idx = math.random(#self.images)

   if window ~= nil then
      self:_set_opt(window, self:_gen_opts())
   end
   return self:sync()
end

---Cycle the loaded `files` and select the next background
---@param window Window WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_forward(window)
   self:rescan()
   if self.current_idx == #self.images then
      self.current_idx = 1
   else
      self.current_idx = self.current_idx + 1
   end
   self:_set_opt(window, self:_gen_opts())
   return self:sync()
end

---Cycle the loaded `files` and select the previous background
---@param window Window WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_back(window)
   self:rescan()
   if self.current_idx == 1 then
      self.current_idx = #self.images
   else
      self.current_idx = self.current_idx - 1
   end
   self:_set_opt(window, self:_gen_opts())
   return self:sync()
end

---Set a specific background from the `files` array
---@param window Window WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
---@param idx number index of the `files` array
function BackDrops:set_img(window, idx)
   if idx > #self.images or idx < 0 then
      wezterm.log_error('Index out of range')
      return
   end

   self.current_idx = idx
   self:_set_opt(window, self:_gen_opts())
   return self:sync()
end

---Preview helpers for the wallpaper picker (Alt+p). They change ONLY the
---backdrop on screen — no cache write, no matugen, no config reload — so
---browsing is instant and free. The two exits are `commit` (keep + theme)
---and `preview_jump` back to the original index (cancel).
---@param window Window
---@param dir integer -1 previous, 0 random, 1 next
function BackDrops:preview_step(window, dir)
   local n = #self.images
   if n == 0 then
      return self
   end
   if dir == 0 then
      self.current_idx = math.random(n)
   else
      self.current_idx = ((self.current_idx - 1 + dir) % n) + 1
   end
   self:_apply(window, self:_gen_opts())
   return self
end

---Jump to a specific image in preview mode (no cache/theme side effects)
---@param window Window
---@param idx number 1-based image index
function BackDrops:preview_jump(window, idx)
   if idx and idx >= 1 and idx <= #self.images then
      self.current_idx = idx
      self:_apply(window, self:_gen_opts())
   end
   return self
end

---Commit the previewed wallpaper: remember it as the chosen one and run the
---theme cascade (matugen -> tmux tokens -> reload) in the background.
---@param window Window
function BackDrops:commit(window)
   self:_remember()
   if window ~= nil then
      self:_set_opt(window, self:_gen_opts())
   end
   return self:sync()
end

---Toggle the focus mode
---@param window Window WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:toggle_focus(window)
   local background_opts = self.no_img and self:_gen_opts() or self:_gen_no_img_opts()
   self.no_img = not self.no_img

   self:_set_opt(window, background_opts)
end

return BackDrops:init()
