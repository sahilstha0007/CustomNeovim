return {
  {
    'gbprod/yanky.nvim',
    event = 'VeryLazy',
    opts = {
      ring = {
        storage = 'shada', -- survives restarts (shada is enabled)
      },
      highlight = {
        on_put = true,
        on_yank = true,
        timer = 150,
      },
    },
    keys = {
      {
        '<leader>sy',
        -- YankyRingHistory renders through vim.ui.select — which snacks
        -- picker now owns (telescope removed)
        '<cmd>YankyRingHistory<cr>',
        desc = 'Yank History',
      },
    },
    config = function(_, opts)
      require('yanky').setup(opts)
    end,
  },
}
