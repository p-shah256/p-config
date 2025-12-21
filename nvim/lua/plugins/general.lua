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
}
