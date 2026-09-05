-- tmux integration. tmux.nvim covers both pane navigation (<C-h/j/k/l>) and
-- resizing (M-h/j/k/l) with default keybindings, so vim-tmux-navigator (which
-- duplicates the navigation maps) is not needed. The tmux side must forward
-- those keys to nvim when it's focused — see the `bind -n C-h/j/k/l
-- if-shell "$is_vim"` lines in ~/.config/tmux/tmux.conf.
return {
  {
    'aserowy/tmux.nvim',
    config = function()
      return require('tmux').setup {
        resize = {
          enable_default_keybindings = true,
        },
      }
    end,
  },
}