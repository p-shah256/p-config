-- sapling.lua — Smartlog-first Sapling UI for Neovim
-- Usage: require('sapling').open()  or  :lua require('sapling').open()

-- The basic idea mirrors the Emacs version:
--   1. Dump `sl ssl` output into a buffer
--   2. For every operation, parse the hash on the cursor line and pass it to sl

-- I could make this agnostic to VC, like make it work with git, but git uses a diff model
-- (stage, unstage, commit etc) so its best to limit this to sapling
-- vim fugitive does all the work for git anyway

---@class SaplingConfig
---@field exec string

---@class SaplingModule
---@field conf SaplingConfig
---@field diff_foldexpr fun(lnum: integer): string

-- TODO: add support to include commit message
--
---@type SaplingModule
local M = {}
---@type SaplingConfig
M.conf = {
        exec = 'sl',
        diff_foldexpr = '',
}

-- HELPERS BEGIN
---@return string
local function find_repo_root()
        -- Walk up from cwd looking for a .sl directory
        local dir = vim.fn.getcwd()
        while dir ~= '/' do
                if vim.fn.isdirectory(dir .. '/.sl') == 1 then return dir end
                dir = vim.fn.fnamemodify(dir, ':h')
        end
        return vim.fn.getcwd()
end

-- runs the sapling subcommand, with some goodies like notify and err handling
---@param ... string
---@return string output
---@return integer|nil err_code
local function run(...)
        ---@type string[]
        local args = { ... }
        ---@type string[]
        local cmd = { M.conf.exec } -- create it, keep a reference
        vim.list_extend(cmd, args) -- extend it in place
        local root = find_repo_root()
        local res = vim.system(cmd, { cwd = root, text = true }):wait()
        if res.code ~= 0 then
                vim.notify(
                        table.concat(cmd, ' ')
                                .. '\nfailed with exit code: '
                                .. res.code
                                .. '\n'
                                .. res.stderr,
                        vim.log.levels.ERROR
                )
                return '', res.code
        end
        return res.stdout or '', nil
end

---@param name string
---@return integer
local function get_or_create_buf(name)
        local existing = vim.fn.bufnr(name)
        if existing ~= -1 then return existing end
        local buf = vim.api.nvim_create_buf(false, true) -- listed, scratch
        vim.api.nvim_buf_set_name(buf, name)
        return buf
end

---@param lnum integer
---@return string
local function diff_foldexpr(lnum)
        local line = vim.fn.getline(lnum)
        if line:match '^diff %-%-git' then
                return '>1' -- file level
        end
        return '=' -- same as previous line
end

-- with the vim.api.nvim_set_option_value you can only set one at a time, which is tedious
-- so its best to craete a helper and do it at once
local function set_buf_options(bufnr, opts)
        for n, val in pairs(opts) do
                vim.api.nvim_set_option_value(n, val, { buf = bufnr })
        end
end

---@return string
local function get_hash_from_diff_buf()
        ---@type string[]
        local lines = vim.api.nvim_buf_get_lines(0, 0, 5, false)
        for _, line in ipairs(lines) do
                ---@type string|nil
                local hash = line:match '^changeset:%s+(%x+)'
                if hash then return hash end
        end
        vim.notify(
                "Can't find changeset hash in buffer, uncommmitted changes",
                vim.log.levels.WARN
        )
        return '.'
end

---@param rev string
---@param root string
---@return string[]
local function cat(rev, root, fpath)
        ---@type string[]
        local cmd = { M.conf.exec, 'cat', '-r', rev, fpath }
        local res = vim.system(cmd, { cwd = root, text = true }):wait()
        return vim.split(res.stdout or '', '\n', { plain = true })
end

---@param lines string[]
---@param name string
---@param fpath string
---@return integer
local function make_diff_buf(lines, name, fpath)
        -- wipe existing as tabclose does not close the buffers
        local existing = vim.fn.bufnr(name)
        if existing ~= -1 then
                vim.api.nvim_buf_delete(existing, { force = true })
        end
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, name)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        set_buf_options(buf, {
                modifiable = false,
                buftype = 'nofile',
                swapfile = false,
        })
        ---@type string|nil
        local ext = fpath:match '%.(%w+)$'
        if ext then
                vim.api.nvim_set_option_value('filetype', ext, { buf = buf })
        end
        return buf
end

-- HELPERS END

-- MAIN SAPLING STARTS HERE
---@type string
local SAPLING_BUF = '*sapling*'
---@type string
local DIFF_BUF = '*sapling-commit*'
---@return integer|nil
local function render_smartlog()
        local buf = get_or_create_buf(SAPLING_BUF)
        local ssl_output, err = run 'ssl'
        if err then return end
        ---@type string[]
        local ssl_lines = vim.split(ssl_output, '\n', { plain = true })
        -- plain = true is like treating the sep as a literal (like escaping it)
        -- Remove trailing empty line that systemlist often appends
        if ssl_lines[#ssl_lines] == '' then
                table.remove(ssl_lines, #ssl_lines)
        end
        set_buf_options(buf, { modifiable = true })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, ssl_lines)
        set_buf_options(
                buf,
                { modifiable = false, buftype = 'nofile', swapfile = false }
        )
        return buf
end

-- ──────────────────────────────────────────────────────────────────
-- HASH EXTRACTION
--
-- sl ssl lines look like:
--   @  c2089707d8  Today at 13:37  shah  origin/master
--   o  93b55ca2d1  Apr 20          shah
--   x  7ea7fe9b38  Apr 19          shah  [Amended as ...]
--
-- The hash is always the first token after the node symbol.
-- ──────────────────────────────────────────────────────────────────
---@return string|nil
local function hash_at_cursor()
        local line = vim.api.nvim_get_current_line()
        --   .*?[@ox+]   — any graph art, then node symbol
        --   %s+         — whitespace
        --   ([0-9a-f]+) — hex hash (capture)
        ---@type string|nil
        local hash = line:match '[@ox+]%s+([0-9a-f]+)'
        if not hash then
                vim.notify('No commit hash on this line', vim.log.levels.WARN)
                return
        end
        return hash
end

-- ASSUMES it will be invoked only on valid fpaths
---@param fpath string path relative to repo root
local function split_diff_view(fpath)
        local root = find_repo_root()
        local c_hash = get_hash_from_diff_buf()
        local old_buf = make_diff_buf(
                cat(c_hash .. '^', root, fpath),
                'sapling-old://' .. fpath,
                fpath
        )
        local new_buf = make_diff_buf(
                cat(c_hash, root, fpath),
                'sapling-new://' .. fpath,
                fpath
        )
        -- special case if asking for uncommitted changes,
        -- override new buf with file on disk
        if c_hash == '.' then
                new_buf = make_diff_buf(
                        vim.fn.readfile(root .. '/' .. fpath),
                        fpath,
                        fpath
                )
        end
        -- open a new tab so closing it brings you straight back,
        -- no cleanup needed
        vim.cmd 'tabnew'
        vim.api.nvim_win_set_buf(0, old_buf)
        vim.cmd 'diffthis'
        vim.cmd 'vsplit'
        vim.api.nvim_win_set_buf(0, new_buf)
        vim.cmd 'diffthis'
        vim.keymap.set('n', 'd', '<cmd>tabc<CR>', {
                desc = 'Close current tab',
                buffer = 0, -- 0 refers to the current buffer
                noremap = true,
                silent = true,
        })
end

-- DIFF VIEW — show commit output in *sapling-commit* buffer
-- this is the homepage of each commit diff view
-- TODO: I hate having thse multi level indents, move the keybinds and its logic out and just associate it with this diff instead of multi level nesting
---@param output string
local function show_commit(output)
        if vim.trim(output) == '' then
                vim.notify('No changes to show', vim.log.levels.INFO)
                return
        end
        local buf = get_or_create_buf(DIFF_BUF)

        ---@type string[]
        local lines = vim.split(output, '\n', { plain = true })
        if lines[#lines] == '' then table.remove(lines) end
        set_buf_options(buf, { modifiable = true })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        set_buf_options(buf, {
                modifiable = false,
                buftype = 'nofile',
                swapfile = false,
                filetype = 'diff',
        })
        vim.wo.foldmethod = 'expr'
        -- provide per line op, vim will iterate over all lines
        vim.wo.foldexpr = "v:lua.require('sapling').diff_foldexpr(v:lnum)"
        vim.wo.foldlevel = 0
        vim.cmd('buffer ' .. buf)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        -- Keymaps for the diff buffer
        local opts = { buffer = buf, silent = true }
        vim.keymap.set(
                'n',
                'q',
                function() vim.cmd('buffer ' .. vim.fn.bufnr(SAPLING_BUF)) end,
                vim.tbl_extend(
                        'error',
                        opts,
                        { desc = 'Back to smartlog buffer' }
                )
        )

        vim.keymap.set(
                'n',
                'D',
                function()
                        local line = vim.api.nvim_get_current_line()
                        ---@type string|nil
                        local fpath = line:match '^diff %-%-git a/.+ b/(.+)'
                        if not fpath then
                                vim.notify(
                                        "cursor must be on a 'diff --git' line",
                                        vim.log.levels.WARN
                                )
                                return
                        end
                        split_diff_view(fpath)
                end,
                vim.tbl_extend('error', opts, {
                        desc = 'Open diff split of changes in current commit and file',
                })
        )

        vim.keymap.set(
                'n',
                '<CR>',
                function()
                        local line = vim.api.nvim_get_current_line()
                        ---@type string|nil
                        local fpath = line:match '^diff %-%-git a/.+ b/(.+)'
                        if not fpath then
                                vim.notify(
                                        "cursor must be on 'diff --git'",
                                        vim.log.levels.WARN
                                )
                                return
                        end
                        vim.cmd.edit(find_repo_root() .. '/' .. fpath)
                end,
                vim.tbl_extend('error', opts, {
                        desc = 'Open file on disk',
                })
        )

        -- cycle thru changed files / hunks
        -- "W" = don't wrap around the file
        -- "b" = search backward
        local diff_pat = '^diff --git'
        local hunk_pat = '^@@'
        vim.keymap.set(
                'n',
                ']c',
                function() vim.fn.search(hunk_pat, 'W') end,
                { buffer = buf, silent = true }
        )
        vim.keymap.set(
                'n',
                '[c',
                function() vim.fn.search(hunk_pat, 'bW') end,
                { buffer = buf, silent = true }
        )
        vim.keymap.set(
                'n',
                ']]',
                function() vim.fn.search(diff_pat, 'W') end,
                { buffer = buf, silent = true }
        )
        vim.keymap.set(
                'n',
                '[[',
                function() vim.fn.search(diff_pat, 'bW') end,
                { buffer = buf, silent = true }
        )
end

---@param buf integer
local function set_ssl_keymaps(buf)
        local opts = { buffer = buf, nowait = true, silent = true }
        vim.keymap.set(
                'n',
                '<CR>',
                function()
                        local hash = hash_at_cursor()
                        if not hash then return end
                        local out, err = run('show', hash, '--git')
                        if err then return end
                        show_commit(out)
                end,
                vim.tbl_extend(
                        'force',
                        opts,
                        { desc = "sl show: Open commit's diff" }
                )
        )
        vim.keymap.set(
                'n',
                'g',
                function() render_smartlog() end,
                { desc = 'Refresh', buffer = buf, nowait = true, silent = true }
        )
        vim.keymap.set(
                'n',
                'd',
                function()
                        local out, err = run('diff', '--git')
                        if err then return end
                        show_commit(out)
                end,
                vim.tbl_extend(
                        'force',
                        opts,
                        { desc = 'sl diff: Show uncommitted changes' }
                )
        )
        vim.keymap.set('n', 'G', function()
                local hash = hash_at_cursor()
                if not hash then return end
                vim.notify('sl goto ' .. hash .. '...', vim.log.levels.INFO)
                local stdout, err = run('goto', hash)
                if err then return end
                render_smartlog()
                vim.notify(stdout, vim.log.levels.INFO)
        end, opts)
        vim.keymap.set('n', 'y', function()
                local hash = hash_at_cursor()
                if not hash then
                        vim.notify(
                                'No commit hash found on this line',
                                vim.log.levels.WARN
                        )
                        return
                end
                vim.fn.setreg('+', hash) -- system clipboard
                vim.fn.setreg('"', hash) -- unnamed register
                vim.notify('Copied: ' .. hash, vim.log.levels.INFO)
        end, opts)
        vim.keymap.set('n', 'r', function()
                local hash = hash_at_cursor()
                if not hash then return end
                vim.api.nvim_feedkeys(
                        ':!'
                                .. M.conf.exec
                                .. ' rebase -s '
                                .. hash
                                .. ' -d remote/master',
                        'n',
                        false
                )
        end, opts)
        vim.keymap.set('n', 'p', function()
                vim.notify('sl pull ...', vim.log.levels.INFO)
                local stdout, err = run 'pull'
                if err then return end
                vim.notify(stdout, vim.log.levels.INFO)
                render_smartlog()
        end, opts)
        vim.keymap.set(
                'n',
                'a',
                function()
                        vim.api.nvim_feedkeys(
                                ':!' .. M.conf.exec .. ' amend --edit',
                                'n',
                                false
                        )
                end,
                opts
        )
        vim.keymap.set('n', 's', function()
                local hash = hash_at_cursor()
                if not hash then return end
                vim.api.nvim_feedkeys(
                        ':!jf submit -un --publish-when-ready',
                        'n',
                        false
                )
                -- puts the command and exits immideatly
        end, opts)
end

vim.api.nvim_create_user_command('Sapling', function()
        local buf = render_smartlog()
        if not buf then return end
        set_ssl_keymaps(buf)
        vim.cmd('buffer ' .. buf)
end, { desc = 'Open Sapling smartlog' })

M.diff_foldexpr = diff_foldexpr

return M
