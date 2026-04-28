-- just overwrite a bunch of functions and create some commands if
-- in sapling repository
local root = vim.fn.systemlist('sl root 2>/dev/null')[1] or ''
if root == '' then return end

vim.api.nvim_create_user_command('Myles', function()
        local fzf = require 'fzf-lua'
        fzf.fzf_live(function(query)
                if type(query) == 'table' then query = query[1] or '' end
                if query == '' then return '' end
                return 'myles --list -n 50 ' .. vim.fn.shellescape(query)
        end, {
                prompt = 'Myles> ',
                exec_empty_query = false,
                cwd = root,
                actions = fzf.defaults.actions.files,
                previewer = 'builtin',
                winopts = {
                        width = 0.95,
                        height = 0.85,
                        preview = {
                                layout = 'vertical',
                                vertical = 'down:40%',
                        },
                },
        })
end, {})
vim.keymap.set('n', '<leader>sf', '<cmd>Myles<cr>', { desc = 'Search files (myles)' })

vim.api.nvim_create_user_command('Zbg', function()
        local fzf = require 'fzf-lua'
        fzf.fzf_live(function(query)
                if type(query) == 'table' then query = query[1] or '' end
                if query == '' then return '' end
                return 'zbgr ' .. query
        end, {
                prompt = 'ZBGR> ',
                exec_empty_query = false,
                cwd = root,
                previewer = 'builtin',
                fn_transform = function(line)
                        -- zbgr outputs fbsource/file:line:col:text
                        -- prepend ~/ and strip col to get ~/fbsource/file:line:text
                        local transformed = '~/' .. line
                        transformed = transformed:gsub('^([^:]+:%d+):%d+:', '%1:')
                        return fzf.make_entry.file(transformed, { file_icons = false })
                end,
                actions = fzf.defaults.actions.files,
        })
end, {})
vim.keymap.set('n', '<leader>sg', '<cmd>Zbg<cr>', { desc = '[s]earch [g]rep' })
-- TODO: in visual mode, just sg for the selected part

-- TODO: eventually we would like to remove this plugin?
vim.pack.add { 'https://github.com/neovim/nvim-lspconfig' }
vim.opt.rtp:prepend '/usr/share/fb-editor-support/nvim'

vim.lsp.enable {
        -- 'pyrefly',            -- Pyrefly type checker
        'rust-analyzer@meta', -- Rust - Run :RustAnalyzerReload on TARGETS changes
        'fb-pyright-ls@meta', -- Python
        'pyre@meta', -- Python type checking
        'thriftlsp@meta', -- Thrift
        'cppls@meta', -- C++
        'buckls@meta', -- Buck
        'buck2@meta', -- Buck/Starlark
        'gopls@meta', -- Golang
        'flow@meta', -- JavaScript/Flow
        'hhvm', -- Hack
        'linttool@meta', -- Linting and formatting
}
function VCS_DIFF_FILE(file) return { 'sl', 'cat', '-r', '.^', file } end
function VCS_DIFF_FILES() return { 'sl', 'status' } end
function VCS_HUNKS()
        return { 'sl', 'diff', '-U0' } -- adding '--change .' would give committed changes
end

-- configerator shouls use python parsers, decorators, folds, etc
vim.treesitter.language.register('python', 'configerator')
