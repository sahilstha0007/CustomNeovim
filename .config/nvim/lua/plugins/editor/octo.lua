-- Octo: GitHub issues, PRs, and discussions from inside nvim (gh CLI
-- backend). Picker backend is snacks (telescope was removed), so every
-- list/search renders in the same glass UI as the rest of the editor.
return {
  {
    'pwntester/octo.nvim',
    cmd = { 'Octo' },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'folke/snacks.nvim',
    },
    opts = {
      -- snacks is the single picker (telescope/fzf removed from the stack)
      picker = 'snacks',
      -- bare `Octo` opens a picker of all subcommands (issue/pr/discussion...)
      enable_builtin = true,
      -- resolve repos via the remote actually present in the project
      default_remote = { 'origin', 'upstream' },
      -- squash by default (matches the team's history style)
      default_merge_method = 'squash',
      -- reviews: show the diff on the right like diffview
      reviews = { focus = 'right', show_virtual_text = true },
      ui = { use_statuscolumn = true, use_signcolumn = false },
    },
    keys = {
      { '<leader>pi', '<cmd>Octo issue list<CR>', desc = 'Issues' },
      { '<leader>pr', '<cmd>Octo pr list<CR>', desc = 'Pull Requests' },
      { '<leader>pd', '<cmd>Octo discussion list<CR>', desc = 'Discussions' },
      { '<leader>pn', '<cmd>Octo notification list<CR>', desc = 'Notifications' },
      {
        '<leader>ps',
        function()
          require('octo.utils').create_base_search_command { include_current_repo = true }
        end,
        desc = 'Search GitHub',
      },
    },
    config = function(_, opts)
      require('octo').setup(opts)
      -- Octo defines its own stock Octo* highlight groups at setup, which
      -- would clobber the wallpaper-themed ones from terminal-colors.lua
      -- (loaded at startup). Re-run the colorscheme so catppuccin's
      -- highlight_overrides (including the Octo section) re-asserts over them.
      pcall(vim.cmd.colorscheme, 'catppuccin')
    end,
  },
}