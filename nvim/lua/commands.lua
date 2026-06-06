-- TODO: need to add folds support for cpp, maybe just embed the treesitter files along with your config?
-- --------------------------------------------------------------------------------
-- TREESITTER
-- --------------------------------------------------------------------------------
-- pulls parsers from github and builds them
-- just run this to install all parsers
-- cd $(mktemp -d) && git clone git@github.com:nvim-treesitter/nvim-treesitter.git
-- cp -r nvim-treesitter/runtime/queries ~/.local/share/nvim/site/
-- if there is a parser version mismatch then use this command TSBuild! <language>
local function install_ts_parser(name, url, force)
        local parser_dir = vim.fn.stdpath 'data' .. '/site/parser'
        vim.fn.mkdir(parser_dir, 'p')
        local so_path = parser_dir .. '/' .. name .. '.so'
        if vim.uv.fs_stat(so_path) and not force then
                print(name .. ' is already installed, skipping. Use :TSBuild! to force.')
                return
        end
        local tmp_path = '/tmp/treesitter/' .. name
        os.execute('rm -rf ' .. tmp_path)
        local output = vim.fn.system('git clone --depth 1 ' .. url .. ' ' .. tmp_path .. ' 2>&1')
        if vim.v.shell_error ~= 0 then
                print('clone failed: ' .. output)
                return
        end
        local src = tmp_path .. '/src'
        local files = src .. '/parser.c'
        if vim.uv.fs_stat(src .. '/scanner.c') then -- if parser has c scanner
                files = files .. ' ' .. src .. '/scanner.c'
        end
        local cc = 'gcc' -- some parsers have a C++ scanner
        if vim.uv.fs_stat(src .. '/scanner.cc') then
                files = files .. ' ' .. src .. '/scanner.cc'
                cc = 'g++'
        end
        local cmd = string.format('%s -o %s -I%s %s -shared -fPIC -O2', cc, so_path, src, files)
        if os.execute(cmd) ~= 0 then
                print('Failed to compile ' .. name)
        else
                print(name .. ' installed to ' .. so_path)
        end
        -- copy query files (highlights.scm, etc.) if they exist
        local queries_src = tmp_path .. '/queries'
        if vim.uv.fs_stat(queries_src) then
                local queries_dst = vim.fn.stdpath 'data' .. '/site/queries/' .. name
                vim.fn.mkdir(queries_dst, 'p')
                os.execute('cp ' .. queries_src .. '/*.scm ' .. queries_dst .. '/')
                print(name .. ' queries installed to ' .. queries_dst)
        end
        os.execute('rm -rf ' .. tmp_path)
end

vim.api.nvim_create_user_command(
        'TSBuild',
        function(opts) install_ts_parser(opts.args, 'git@github.com:tree-sitter/tree-sitter-' .. opts.args .. '.git', opts.bang) end,
        { nargs = 1, bang = true }
)

vim.api.nvim_create_autocmd('FileType', {
        callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
})

-- --------------------------------------------------------------------------------
-- TREESITTER CONTEXT
-- --------------------------------------------------------------------------------

local context_types = {
        function_definition = true,
        function_declaration = true,
        method_definition = true,
        method_declaration = true,
        class_definition = true,
        class_declaration = true,
        if_statement = true,
        elif_clause = true,
        else_clause = true,
        for_statement = true,
        for_in_statement = true,
        while_statement = true,
        with_statement = true,
        try_statement = true,
        except_clause = true,
        match_statement = true,
        case_clause = true,
}

local function get_context(node)
        local parts = {}
        while node do
                if context_types[node:type()] then
                        local line = vim.api.nvim_buf_get_lines(0, node:start(), node:start() + 1, false)[1]
                        table.insert(parts, 1, vim.trim(line))
                end
                node = node:parent()
        end
        return table.concat(parts, ' > ')
end

vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        callback = function(ev)
                if vim.api.nvim_buf_line_count(ev.buf) > 5000 then return end
                local node = vim.treesitter.get_node()
                if not node then
                        vim.wo.winbar = ''
                        return
                end
                -- winbar value is parsed as a statusline format string: '%' starts a
                -- format spec, so unescaped '%' in source code triggers E539. Escape
                -- '%' -> '%%' and strip control chars.
                local ctx = get_context(node):gsub('%c', ' '):gsub('%%', '%%%%')
                vim.wo.winbar = ctx
        end,
})

-- --------------------------------------------------------------------------------
-- ILLUMINATE
-- --------------------------------------------------------------------------------
local ns_id = vim.api.nvim_create_namespace 'illuminate'

vim.api.nvim_set_hl(0, 'illuminate', { underline = true })

local function clear(bufnr)
        vim.lsp.buf.clear_references()
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

local function highlight(bufnr)
        clear(bufnr)
        -- if lsp supports
        local clients = vim.lsp.get_clients { bufnr = 0 }
        for _, client in ipairs(clients) do
                if client:supports_method('textDocument/documentHighlight', bufnr) then
                        vim.lsp.buf.document_highlight()
                        return
                end
        end
        -- Skip large files for performance
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        if line_count > 5000 then return end
        local cursor_n = vim.treesitter.get_node()
        if not cursor_n then return end
        local cursor_text = vim.treesitter.get_node_text(cursor_n, bufnr)
        local root = vim.treesitter.get_parser(bufnr):parse()[1]:root()
        if not cursor_n:parent() then return end -- root
        local sr, _, er, _ = cursor_n:range()
        if sr - er > 0 then return end -- multiline
        if not cursor_text or cursor_text == '' or #cursor_text <= 1 then return end
        local function walk(n) -- if same type highlight else keep walking to other children
                if cursor_n:type() == n:type() and vim.treesitter.get_node_text(n, bufnr) == cursor_text then
                        local sline, scol, er, ec = n:range()
                        vim.api.nvim_buf_set_extmark(bufnr, ns_id, sline, scol, { end_row = er, end_col = ec, hl_group = 'illuminate' })
                end
                for child in n:iter_children() do
                        walk(child)
                end
        end
        walk(root)
end

vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        callback = function(ev) highlight(ev.buf) end,
})

vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'BufLeave' }, {
        callback = function(ev) clear(ev.buf) end,
})

-- --------------------------------------------------------------------------------
-- LSP COMPLETIONS
-- --------------------------------------------------------------------------------
vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
                local client = vim.lsp.get_client_by_id(ev.data.client_id)
                if client ~= nil and client:supports_method 'textDocument/completion' then
                        -- expand triggerCharacters to include all alphanumeric + underscore
                        -- so clangd fires on every keypress, not just . -> ::
                        local chars = vim.split('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_', '')
                        local caps = client.server_capabilities or {}
                        local provider = caps.completionProvider or {}
                        local existing = provider.triggerCharacters or {}
                        for _, c in ipairs(chars) do
                                existing[#existing + 1] = c
                        end
                        provider.triggerCharacters = existing
                        vim.lsp.completion.enable(true, client.id, ev.buf, {
                                autotrigger = true,
                        })
                        -- stop nvim from mixing in buffer words before clangd fires
                        vim.bo[ev.buf].complete = ''
                        vim.schedule(function() vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc' end)
                end
        end,
})

-- --------------------------------------------------------------------------------
-- COPY PATH
-- --------------------------------------------------------------------------------
vim.api.nvim_create_user_command('CopyPath', function(opts)
        local path = vim.fn.expand '%:p'
        if opts.range > 0 then
                if opts.line1 == opts.line2 then
                        path = path .. ':' .. opts.line1
                else
                        path = path .. ':' .. opts.line1 .. '-' .. opts.line2
                end
        end
        vim.fn.setreg('+', path)
        vim.notify('Copied: ' .. path)
end, { range = true })
vim.keymap.set('n', '<leader>cp', '<cmd>CopyPath<cr>', { desc = 'Copy path' })
vim.keymap.set('v', '<leader>cp', ':CopyPath<cr>', { desc = 'Copy path with lines' })

-- --------------------------------------------------------------------------------
-- SIGNIFY: GUTTER SIGNS + DIFF VIEW
-- --------------------------------------------------------------------------------
local diff_ns = vim.api.nvim_create_namespace 'diffs'
-- returns the shell command to get the base version of a file
-- (overridden in meta.lua for sapling)
function VCS_DIFF_FILE(file) return { 'git', 'show', 'HEAD:' .. vim.fn.fnamemodify(file, ':.') } end
function VCS_HUNKS() return { 'git', 'diff', '--name-status' } end

local hunk_cache = {}

vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
        callback = function(ev)
                hunk_cache[ev.buf] = {} -- reset and init
                vim.api.nvim_buf_clear_namespace(ev.buf, diff_ns, 0, -1)
                if not vim.api.nvim_buf_is_valid(ev.buf) then return end
                local file = vim.api.nvim_buf_get_name(ev.buf)
                if file == '' then return end
                vim.system(
                        VCS_DIFF_FILE(file),
                        {},
                        vim.schedule_wrap(function(r)
                                if r.code ~= 0 or not vim.api.nvim_buf_is_valid(ev.buf) then return end
                                local curr = table.concat(vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false), '\n') .. '\n'
                                for _, h in ipairs(vim.text.diff(r.stdout, curr, { result_type = 'indices' })) do
                                        local sign = h[2] == 0 and { '+', 'DiffAdd' } or h[4] == 0 and { '-', 'DiffDelete' } or { '~', 'DiffChange' }
                                        local from = h[4] == 0 and h[3] or h[3]
                                        local to = h[4] == 0 and h[3] or h[3] + h[4] - 1
                                        for lnum = from, to do
                                                vim.api.nvim_buf_set_extmark(ev.buf, diff_ns, lnum - 1, 0, { sign_text = sign[1], sign_hl_group = sign[2] })
                                        end
                                        table.insert(hunk_cache[ev.buf], { h[1], h[2], h[3], h[4] })
                                end
                        end)
                )
        end,
})

vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
        callback = function(ev) hunk_cache[ev.buf] = nil end,
})

-- with expr the function’s return value becomes “the keys to execute next”
-- read more on the docs on why do we need scheudle instead of just calling
-- it directly?
vim.keymap.set('n', '[c', function()
        if vim.wo.diff then return '[c' end
        local hunks = hunk_cache[vim.api.nvim_get_current_buf()]
        if not hunks or #hunks == 0 then return '<Ignore>' end
        local target = hunks[#hunks][3] + hunks[#hunks][4] - 1
        for i = #hunks, 1, -1 do
                local lnum = hunks[i][3] + hunks[i][4] - 1
                if lnum < vim.fn.line '.' then
                        target = lnum
                        break
                end
        end
        vim.schedule(function() vim.fn.cursor(target, 1) end)
        return '<Ignore>'
end, { desc = 'Prev change', expr = true })

vim.keymap.set('n', ']c', function()
        if vim.wo.diff then return ']c' end
        local hunks = hunk_cache[vim.api.nvim_get_current_buf()]
        if not hunks or #hunks == 0 then return '<Ignore>' end
        local target = hunks[1][3]
        for i = 1, #hunks do
                if hunks[i][3] > vim.fn.line '.' then
                        target = hunks[i][3]
                        break
                end
        end
        vim.schedule(function() vim.fn.cursor(target, 1) end)
        return '<Ignore>'
end, { desc = 'Next change', expr = true })
-- SIGNIFY end

-- --------------------------------------------------------------------------------
-- indent guides
-- --------------------------------------------------------------------------------
-- :verbose setlocal tabstop? shiftwidth? softtabstop? expandtab? filetype? indentexpr?
local function indent_options_are_default() return vim.bo.tabstop == 8 and vim.bo.shiftwidth == 8 and vim.bo.softtabstop == 0 and not vim.bo.expandtab end

local function round_indent_width(n)
        if not n then
                return nil
        elseif n <= 2 then
                return 2
        elseif n <= 4 then
                return 4
        else
                return 8
        end
end

local function detect_indent()
        local lines = vim.api.nvim_buf_get_lines(0, 0, 200, false)
        local min_indent = nil

        for _, line in ipairs(lines) do
                local spaces = line:match '^( +)%S'
                if spaces then
                        local n = #spaces
                        if not min_indent or n < min_indent then min_indent = n end
                end
        end

        return round_indent_width(min_indent)
end

local function indent_width()
        if indent_options_are_default() then return detect_indent() or 8 end
        return vim.fn.shiftwidth()
end

local function update_leadmultispace()
        local sw = indent_width()

        if sw > 1 then
                local listchars = vim.opt_local.listchars:get()
                listchars.leadmultispace = '▏' .. string.rep(' ', sw - 1)
                vim.opt_local.listchars = listchars
        end
end

vim.api.nvim_create_autocmd({ 'BufWinEnter', 'FileType' }, {
        group = vim.api.nvim_create_augroup('IndentGuides', { clear = true }),
        callback = update_leadmultispace,
})
