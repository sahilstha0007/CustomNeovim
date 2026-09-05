local Config = require('config')

require('utils.backdrops')
   :set_images_dir(require('wezterm').home_dir .. '/Pictures/wallpaper/')
   :scan_images_dir()
   :exclude_files({
      'wallhaven-x1elzo_1920x1080.png',
      'Generated Image September 16, 2025 - 11_32PM.png',
      'wallhaven-49mqg8.jpg',
   })
   :from_cache_or_random()

require('events.left-status').setup()
require('events.right-status').setup({ date_format = '%a %H:%M:%S' })
require('events.tab-title').setup({
   hide_active_tab_unseen = true,
   unseen_icon = 'numbered_box',
   show_progress = true,
})
require('events.new-tab-button').setup()
require('events.gui-startup').setup()

return Config:init()
   :append(require('config.appearance'))
   :append(require('config.bindings'))
   :append(require('config.domains'))
   :append(require('config.fonts'))
   :append(require('config.general'))
   :append(require('config.launch')).options
