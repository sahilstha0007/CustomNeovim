local wezterm = require('wezterm')
local umath = require('utils.math')
local Cells = require('utils.cells')
local OptsValidator = require('utils.opts-validator')
local tokens = require('utils.tokens')

local nf = wezterm.nerdfonts
local attr = Cells.attr

-- pick(dark, light): dark values match the old mocha chrome (vivid pastels on
-- the translucent pill); light values are their latte relatives so the icons
-- stay visible on the lighter pill.
local function pick(dark, light)
   return tokens.light and light or dark
end

---@alias Event.RightStatusOptionsInput { date_format?: string }

---@alias Event.RightStatusOptions { date_format: string }

---Setup options for the right status bar
---@type OptsValidator
local EVENT_OPTS = OptsValidator:new({
   {
      name = 'date_format',
      type = 'string',
      default = '%a %H:%M:%S',
   },
})

local M = {}

local ICON_SEPARATOR = nf.oct_dash
local ICON_DATE = nf.fa_calendar
local ICON_HOST = nf.md_laptop
local ICON_UPTIME = nf.md_timer_outline

---@type string[]
local discharging_icons = {
   nf.md_battery_10,
   nf.md_battery_20,
   nf.md_battery_30,
   nf.md_battery_40,
   nf.md_battery_50,
   nf.md_battery_60,
   nf.md_battery_70,
   nf.md_battery_80,
   nf.md_battery_90,
   nf.md_battery,
}
---@type string[]
local charging_icons = {
   nf.md_battery_charging_10,
   nf.md_battery_charging_20,
   nf.md_battery_charging_30,
   nf.md_battery_charging_40,
   nf.md_battery_charging_50,
   nf.md_battery_charging_60,
   nf.md_battery_charging_70,
   nf.md_battery_charging_80,
   nf.md_battery_charging_90,
   nf.md_battery_charging,
}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   date      = { fg = pick('#fab387', '#c96a0a'), bg = tokens.glass },
   host      = { fg = pick('#cba6f7', '#6a4fc4'), bg = tokens.glass },
   uptime    = { fg = pick('#89dceb', '#0b7285'), bg = tokens.glass },
   battery   = { fg = pick('#f9e2af', '#8f6d00'), bg = tokens.glass },
   separator = { fg = pick('#74c7ec', '#126e96'), bg = tokens.glass }
}

local cells = Cells:new()

cells
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('host_icon', ICON_HOST .. '  ', colors.host, attr(attr.intensity('Bold')))
   :add_segment('host_text', '', colors.host, attr(attr.intensity('Bold')))
   :add_segment('uptime_icon', '', colors.uptime, attr(attr.intensity('Bold')))
   :add_segment('uptime_text', '', colors.uptime, attr(attr.intensity('Bold')))
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))

---@return string, string
local function battery_info()
   -- ref: https://wezfurlong.org/wezterm/config/lua/wezterm/battery_info.html

   local charge = ''
   local icon = ''

   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   return charge, icon .. ' '
end

---Uptime as `Xd Xh` / `Xh Xm` / `Xm`; `nil` on platforms without `/proc/uptime`
---@return string?
local function uptime()
   local f = io.open('/proc/uptime', 'r')
   if not f then
      return nil
   end

   local line = f:read('*l')
   f:close()

   local secs = tonumber((line or ''):match('^(%d+)'))
   if not secs then
      return nil
   end

   local days = math.floor(secs / 86400)
   local hours = math.floor((secs % 86400) / 3600)
   local mins = math.floor((secs % 3600) / 60)

   if days > 0 then
      return string.format('%dd %dh', days, hours)
   elseif hours > 0 then
      return string.format('%dh %dm', hours, mins)
   end
   return string.format('%dm', mins < 1 and 1 or mins)
end

---@param opts? Event.RightStatusOptionsInput Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   ---@cast valid_opts Event.RightStatusOptions

   wezterm.on('update-status', function(window, _pane)
      local battery_text, battery_icon = battery_info()
      local uptime_text = uptime()
      local user = os.getenv('USER') or os.getenv('USERNAME') or 'user'
      local host = user .. '@' .. wezterm.hostname()

      cells
         :update_segment_text('date_text', wezterm.strftime(valid_opts.date_format))
         :update_segment_text('host_text', host)
         :update_segment_text('uptime_icon', uptime_text and (ICON_UPTIME .. '  ') or '')
         :update_segment_text('uptime_text', uptime_text or '')
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)

      window:set_right_status(
         wezterm.format(
            cells:render({
               'date_icon',
               'date_text',
               'separator',
               'host_icon',
               'host_text',
               'separator',
               'uptime_icon',
               'uptime_text',
               'separator',
               'battery_icon',
               'battery_text',
            })
         )
      )
   end)
end

return M
