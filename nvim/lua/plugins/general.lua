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
      vim.g.signify_line_highlight = 1 -- Highlight changed lines
      vim.g.signify_fold_context = { 1, 3 } -- Show 1 line before, 3 after in folds
      vim.g.signify_sign_add = '+'
      vim.g.signify_sign_change = '~'
      vim.g.signify_sign_delete = '-'
      vim.g.signify_sign_delete_first_line = ''
      vim.g.signify_sign_change_delete = '-'
      vim.api.nvim_set_hl(0, 'SignifyLineAdd', { link = 'DiffAdd' })
      vim.api.nvim_set_hl(0, 'SignifyLineChange', { link = 'DiffChange' })
      vim.api.nvim_set_hl(0, 'SignifyLineDelete', { link = 'DiffDelete' })
    end,
  },

  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
      }
      -- To allow other plugins to add linters to require('lint').linters_by_ft,
      -- instead set linters_by_ft like this:
      -- lint.linters_by_ft = lint.linters_by_ft or {}
      -- lint.linters_by_ft['markdown'] = { 'markdownlint' }
      --
      -- However, note that this will enable a set of default linters,
      -- which will cause errors unless these tools are available:
      -- {
      --   clojure = { "clj-kondo" },
      --   dockerfile = { "hadolint" },
      --   inko = { "inko" },
      --   janet = { "janet" },
      --   json = { "jsonlint" },
      --   markdown = { "vale" },
      --   rst = { "vale" },
      --   ruby = { "ruby" },
      --   terraform = { "tflint" },
      --   text = { "vale" }
      -- }
      --
      -- You can disable the default linters by setting their filetypes to nil:
      -- lint.linters_by_ft['clojure'] = nil
      -- lint.linters_by_ft['dockerfile'] = nil
      -- lint.linters_by_ft['inko'] = nil
      -- lint.linters_by_ft['janet'] = nil
      -- lint.linters_by_ft['json'] = nil
      -- lint.linters_by_ft['markdown'] = nil
      -- lint.linters_by_ft['rst'] = nil
      -- lint.linters_by_ft['ruby'] = nil
      -- lint.linters_by_ft['terraform'] = nil
      -- lint.linters_by_ft['text'] = nil
      -- Create autocommand which carries out the actual linting
      -- on the specified events.
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- Only run the linter in buffers that you can modify in order to
          -- avoid superfluous noise, notably within the handy LSP pop-ups that
          -- describe the hovered symbol using Markdown.
          if vim.bo.modifiable then
            lint.try_lint()
          end
        end,
      })
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
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {},
  },

  { -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help ibl`
    main = 'ibl',
    opts = {},
  },

  {
    'stevearc/oil.nvim',
    opts = {},
    -- Optional dependencies
    dependencies = { { 'nvim-mini/mini.icons', opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
    config = function()
      require('oil').setup()
      vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
    end,
  },

  {
    'ojroques/nvim-osc52',
    config = function()
      require('osc52').setup {
        max_length = 0,
        silent = true,
        trim = false,
      }

      vim.api.nvim_create_autocmd('TextYankPost', {
        callback = function()
          if vim.v.event.regname == '' then
            require('osc52').copy_register '"'
          end
        end,
      })
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
      vim.cmd.colorscheme 'gruvbox-material'
    end,
  },
  { 'projekt0n/github-nvim-theme', name = 'github-theme' },
  { 'nyoom-engineering/oxocarbon.nvim' },

  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type Flash.Config
    opts = {},
    keys = {
      {
        '<leader>j',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump()
        end,
        desc = 'Flash Jump',
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
    },
  },

  {
    'RRethy/vim-illuminate',
    event = 'LazyFile',
    opts = {
      delay = 200,
      large_file_cutoff = 2000,
      large_file_overrides = {
        providers = { 'lsp' },
      },
    },
  },

  {
    'nvim-orgmode/orgmode',
    event = 'VeryLazy',
    ft = { 'org' },
    config = function()
      -- Setup orgmode
      require('orgmode').setup {
        org_agenda_files = '~/orgfiles/**/*',
        org_default_notes_file = '~/orgfiles/refile.org',
        org_hide_emphasis_markers = true,
        org_indent_mode = 'noindent', -- no virtual indent
        org_adapt_indentation = false, -- don't auto-indent content under headings
        org_startup_indented = false, -- don't start with indent mode
      }
      -- Org heading separators (vim help style)
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'org',
        callback = function()
          -- No auto-indent
          vim.opt_local.autoindent = false
          vim.opt_local.smartindent = false
          vim.opt_local.cindent = false
          vim.opt_local.indentexpr = ''
          -- Disable signify, open all folds
          vim.cmd 'silent! SignifyDisableAll'
          vim.opt_local.foldenable = false
          -- Insert separator below current line
          -- <leader>= for level 1 (===), <leader>- for level 2 (---)
          vim.keymap.set('n', '<leader>=', function()
            local row = vim.api.nvim_win_get_cursor(0)[1]
            vim.api.nvim_buf_set_lines(0, row, row, false, { string.rep('=', 79) })
          end, { buffer = true, desc = 'Insert === separator below' })
          vim.keymap.set('n', '<leader>-', function()
            local row = vim.api.nvim_win_get_cursor(0)[1]
            local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
            local len = #line
            if len > 0 then
              vim.api.nvim_buf_set_lines(0, row, row, false, { string.rep('-', len) })
            end
          end, { buffer = true, desc = 'Insert --- underline below' })
        end,
      })
      -- NOTE: If you are using nvim-treesitter with ~ensure_installed = 'all'~ option
      -- add ~org~ to ignore_install
      -- require('nvim-treesitter.configs').setup({
      --   ensure_installed = 'all',
      --   ignore_install = { 'org' },
      -- })
    end,
  },

  { 'dhruvasagar/vim-table-mode' },
}
