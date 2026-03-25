return {

  {
    'mhinz/vim-signify',
    init = function(_)
      vim.g.signify_vcs_cmds = {
        hg = 'sl diff -r .^ --config diff.unified=0 --config diff.noprefix=True --nodates %f',
      }
    end,
    config = function(_, _)
      vim.api.nvim_set_hl(0, 'SignifySignAdd', { link = 'GitSignsAdd' })
      vim.api.nvim_set_hl(0, 'SignifySignChange', { link = 'GitSignsChange' })
      vim.api.nvim_set_hl(0, 'SignifySignChangeDelete', { link = 'GitSignsChange' })
      vim.api.nvim_set_hl(0, 'SignifySignDelete', { link = 'GitSignsDelete' })
      vim.api.nvim_set_hl(0, 'SignifySignDeleteFirstLine', { link = 'GitSignsDelete' })
      -- Performance improvements
      vim.g.signify_update_on_bufenter = 1 -- Update when entering buffer
      vim.g.signify_update_on_focusgained = 1 -- Update when gaining focus
      vim.g.signify_realtime = 0 -- Disable real-time updates
      -- Update on save
      vim.api.nvim_create_autocmd('BufWritePost', {
        pattern = '*',
        callback = function()
          vim.cmd 'SignifyRefresh'
        end,
      })
      -- vim.g.signify_line_highlight = 1 -- Highlight changed lines
      vim.g.signify_fold_context = { 1, 3 } -- Show 1 line before, 3 after in folds
      vim.g.signify_sign_add = '+'
      vim.g.signify_sign_change = '~'
      vim.g.signify_sign_delete = '-'
      vim.g.signify_sign_delete_first_line = ''
      vim.g.signify_sign_change_delete = '-'
      vim.api.nvim_set_hl(0, 'SignifyLineAdd', { link = 'DiffAdd' })
      vim.api.nvim_set_hl(0, 'SignifyLineChange', { link = 'DiffChange' })
      vim.api.nvim_set_hl(0, 'SignifyLineDelete', { link = 'DiffDelete' })
      vim.keymap.set('n', '<leader>ts', '<cmd>SignifyToggle<cr>', { desc = '[t]oggle [s]ignify' })
    end,
  },


  {
    dir = vim.fn.expand '~/.config/nvim/forks/diffview.nvim',
    name = 'diffview.nvim',
    opts = {
      -- vim.keymap.set('n', '<leader>S', '<cmd>Diff<cr>', { desc = 'ZBGR search' })
    },
  },

  {
    'nvim-treesitter/nvim-treesitter-context',
    event = 'VeryLazy',
    opts = {
      enable = true,
      max_lines = 5, -- How many lines of context to show
      min_window_height = 0, -- Minimum editor window height to enable context
      line_numbers = true,
      multiline_threshold = 20, -- Maximum number of lines to show for a single context
      trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded
      mode = 'cursor', -- Line used to calculate context. Choices: 'cursor', 'topline'
      -- Separator between context and content. Should be a single character string, like '-'.
      -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
      separator = nil,
      zindex = 20, -- The Z-index of the context window
      on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching to a given buffer
    },
  },



  {
    'stevearc/oil.nvim',
    -- Optional dependencies
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
    config = function()
      require('oil').setup()
      vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
    end,
  },


  {
    'sainnhe/gruvbox-material',
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.gruvbox_material_background = 'hard'
      vim.g.gruvbox_material_foreground = 'material'
      vim.g.gruvbox_material_better_performance = 1
    end,
  },
  { 'projekt0n/github-nvim-theme', name = 'github-theme' },
  { 'nyoom-engineering/oxocarbon.nvim' },
  {
    'zenbones-theme/zenbones.nvim',
    dependencies = 'rktjmp/lush.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'zenbones'
    end,
  },

  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type Flash.Config
    opts = {},
    keys = {
      {
        's',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump()
        end,
        desc = 'Flash',
      },
      {
        'S',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').treesitter()
        end,
        desc = 'Flash Treesitter',
      },
      {
        'r',
        mode = 'o',
        function()
          require('flash').remote()
        end,
        desc = 'Remote Flash',
      },
      {
        'R',
        mode = { 'o', 'x' },
        function()
          require('flash').treesitter_search()
        end,
        desc = 'Treesitter Search',
      },
      {
        '<c-s>',
        mode = { 'c' },
        function()
          require('flash').toggle()
        end,
        desc = 'Toggle Flash Search',
      },
      vim.keymap.set({ 'n', 'x', 'o' }, '<c-space>', function()
        require('flash').treesitter {
          actions = {
            ['<c-space>'] = 'next',
            ['<BS>'] = 'prev',
          },
        }
      end, { desc = 'Treesitter incremental selection' }),
    },
  },


  { 'dhruvasagar/vim-table-mode', cmd = 'TableModeToggle' },
}
