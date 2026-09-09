-- AI agent CLI picker (<leader>a): choose Claude Code or opencode, opens in
-- a right tmux pane when inside tmux (pairs with the terminal stack) or a
-- floating snacks terminal outside it. Uses `vim.ui.select`, which snacks
-- owns — no extra plugin.
return {
  'nvim-lua/plenary.nvim',
  lazy = true,
  keys = {
    {
      '<leader>a',
      function()
        local agents = {
          { name = 'Claude Code', cmd = 'claude' },
          { name = 'opencode', cmd = 'opencode' },
        }
        vim.ui.select(agents, {
          prompt = 'AI Agent',
          format_item = function(item)
            return item.name
          end,
        }, function(choice)
          if not choice then
            return
          end
          if vim.env.TMUX then
            -- right pane in the current tmux window, cwd follows nvim
            vim.system({
              'tmux',
              'split-window',
              '-h',
              '-c',
              vim.fn.getcwd(),
              choice.cmd,
            }, { text = true })
          else
            require('snacks.terminal').open(choice.cmd, {
              win = { position = 'float' },
            })
          end
        end)
      end,
      desc = 'AI Agent (Claude Code / opencode)',
    },
  },
}
