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
---@type SaplingModule
local M = {
        ---@type SaplingConfig
        conf = { exec = 'sl' },
        diff_foldexpr = function(_) return '=' end, -- real impl assigned at bottom
}

---@type string
local SAPLING_BUF = '*sapling*'
---@type string
local DIFF_BUF = '*sapling-commit*'

-- ──────────────────────────────────────────────────────────────────
-- HELPERS
-- ──────────────────────────────────────────────────────────────────

---@param start string|nil  directory to start walking from (defaults to cwd)
---@return string
local function find_repo_root(start)
        -- Walk up from `start` looking for a .sl directory
        local dir = start or vim.fn.getcwd()
        while dir ~= '/' do
                if vim.fn.isdirectory(dir .. '/.sl') == 1 then return dir end
                dir = vim.fn.fnamemodify(dir, ':h')
        end
        return start or vim.fn.getcwd()
end

-- runs the sapling subcommand, with some goodies like notify and err handling
---@param ... string
---@return string output
---@return integer|nil err_code
local function run(...)
        local cmd = { M.conf.exec }
        vim.list_extend(cmd, { ... })
        local res = vim.system(cmd, { cwd = find_repo_root(), text = true }):wait()
        if res.code ~= 0 then
                vim.notify(table.concat(cmd, ' ') .. '\nfailed with exit code: ' .. res.code .. '\n' .. res.stderr, vim.log.levels.ERROR)
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

-- with vim.api.nvim_set_option_value you can only set one at a time, which is tedious
-- so its best to create a helper and do it at once
local function set_buf_options(bufnr, opts)
        for n, val in pairs(opts) do
                vim.api.nvim_set_option_value(n, val, { buf = bufnr })
        end
end

-- Fill a scratch buffer with `lines`, applying common read-only opts.
---@param buf integer
---@param lines string[]
---@param extra_opts table|nil
local function fill_buf(buf, lines, extra_opts)
        if lines[#lines] == '' then table.remove(lines) end
        set_buf_options(buf, { modifiable = true })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local opts = { modifiable = false, buftype = 'nofile', swapfile = false }
        if extra_opts then opts = vim.tbl_extend('force', opts, extra_opts) end
        set_buf_options(buf, opts)
end

---@param lnum integer
---@return string
local function diff_foldexpr(lnum)
        local line = vim.fn.getline(lnum)
        if line:match '^diff %-%-git' then return '>1' end -- file level
        return '=' -- same as previous line
end

-- sl ssl lines look like:
--   @  c2089707d8  Today at 13:37  shah  origin/master
--   o  93b55ca2d1  Apr 20          shah
-- The hash is always the first token after the node symbol [@ox+].
---@return string|nil
local function hash_at_cursor()
        local hash = vim.api.nvim_get_current_line():match '[@ox+]%s+([0-9a-f]+)'
        if not hash then vim.notify('No commit hash on this line', vim.log.levels.WARN) end
        return hash
end

-- Pull file path out of a `diff --git a/... b/...` line on the cursor.
-- Returns an ABSOLUTE path (repo root prepended).
---@param warn string
---@return string|nil
local function fpath_at_cursor(warn)
        local rel = vim.api.nvim_get_current_line():match '^diff %-%-git a/.+ b/(.+)'
        if not rel then
                vim.notify(warn, vim.log.levels.WARN)
                return nil
        end
        return find_repo_root() .. '/' .. rel
end

-- Scan the top of the diff buffer for `changeset: <hash>`, else "." (uncommitted).
---@return string
local function get_hash_from_diff_buf()
        local lines = vim.api.nvim_buf_get_lines(0, 0, 5, false)
        for _, line in ipairs(lines) do
                local hash = line:match '^changeset:%s+(%x+)'
                if hash then return hash end
        end
        vim.notify("Can't find changeset hash in buffer, uncommmitted changes", vim.log.levels.WARN)
        return '.'
end

-- `fpath` must be absolute.
---@param rev string
---@param fpath string
---@return string[]
local function cat(rev, fpath)
        local cmd = { M.conf.exec, 'cat', '-r', rev, fpath }
        local res = vim.system(cmd, { cwd = find_repo_root(), text = true }):wait()
        return vim.split(res.stdout or '', '\n', { plain = true })
end

-- Build a one-off scratch buffer for the side-by-side diff tab.
---@param lines string[]
---@param name string
---@param fpath string
---@return integer
local function make_diff_buf(lines, name, fpath)
        -- wipe existing as tabclose does not close the buffers
        local existing = vim.fn.bufnr(name)
        if existing ~= -1 then vim.api.nvim_buf_delete(existing, { force = true }) end
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, name)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        set_buf_options(buf, { modifiable = false, buftype = 'nofile', swapfile = false })
        local ext = fpath:match '%.(%w+)$'
        if ext then vim.api.nvim_set_option_value('filetype', ext, { buf = buf }) end
        return buf
end

-- Build a per-buffer keymap setter. Returns a `map(lhs, rhs, desc)` function
-- that merges opts with `tbl_extend('error', ...)` so duplicates blow up loudly.
---@param base_opts table
---@return fun(lhs: string, rhs: function|string, desc: string)
local function keymapper(base_opts)
        return function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, vim.tbl_extend('error', base_opts, { desc = desc })) end
end

-- ──────────────────────────────────────────────────────────────────
-- MAIN SAPLING
-- ──────────────────────────────────────────────────────────────────

---@return integer|nil
local function render_smartlog()
        local buf = get_or_create_buf(SAPLING_BUF)
        local ssl_output, err = run 'ssl'
        if err then return end
        local lines = vim.split(ssl_output, '\n', { plain = true })
        fill_buf(buf, lines)
        return buf
end

-- ASSUMES it will be invoked only on valid fpaths
---@param fpath string ABSOLUTE path to the file
---@param hash string|nil explicit changeset; falls back to scanning current buf
local function split_diff_view(fpath, hash)
        local c_hash = hash or get_hash_from_diff_buf()
        local old_buf = make_diff_buf(cat(c_hash .. '^', fpath), 'sapling-old://' .. fpath, fpath)
        local new_buf = make_diff_buf(cat(c_hash, fpath), 'sapling-new://' .. fpath, fpath)
        -- special case if asking for uncommitted changes, override new buf with file on disk
        if c_hash == '.' then new_buf = make_diff_buf(vim.fn.readfile(fpath), fpath, fpath) end
        -- open a new tab so closing it brings you straight back, no cleanup needed
        vim.cmd 'tabnew'
        vim.api.nvim_win_set_buf(0, old_buf)
        vim.cmd 'diffthis'
        vim.cmd 'vsplit'
        vim.api.nvim_win_set_buf(0, new_buf)
        vim.cmd 'diffthis'
        vim.keymap.set('n', 'd', '<cmd>tabc<CR>', {
                desc = 'Close current tab',
                buffer = 0,
                noremap = true,
                silent = true,
        })
end

-- Keymaps for the *sapling-commit* (diff) buffer.
---@param buf integer
local function set_commit_keymaps(buf)
        local map = keymapper { buffer = buf, silent = true }
        map('q', function() vim.cmd('buffer ' .. vim.fn.bufnr(SAPLING_BUF)) end, 'Back to smartlog buffer')
        map('D', function()
                local fpath = fpath_at_cursor "cursor must be on a 'diff --git' line"
                if fpath then split_diff_view(fpath) end
        end, 'Open diff split of changes in current commit and file')
        map('<CR>', function()
                local fpath = fpath_at_cursor "cursor must be on 'diff --git'"
                if fpath then vim.cmd.edit(fpath) end
        end, 'Open file on disk')
        -- cycle thru changed files / hunks.  W = no wrap, b = backward.
        map(']c', function() vim.fn.search('^@@', 'W') end, 'Next hunk')
        map('[c', function() vim.fn.search('^@@', 'bW') end, 'Prev hunk')
        map(']]', function() vim.fn.search('^diff --git', 'W') end, 'Next file')
        map('[[', function() vim.fn.search('^diff --git', 'bW') end, 'Prev file')
end

-- DIFF VIEW — show commit output in *sapling-commit* buffer
---@param output string
local function show_commit(output)
        if vim.trim(output) == '' then
                vim.notify('No changes to show', vim.log.levels.INFO)
                return
        end
        local buf = get_or_create_buf(DIFF_BUF)
        fill_buf(buf, vim.split(output, '\n', { plain = true }), { filetype = 'diff' })
        vim.wo.foldmethod = 'expr'
        -- provide per line op, vim will iterate over all lines
        vim.wo.foldexpr = "v:lua.require('sapling').diff_foldexpr(v:lnum)"
        vim.wo.foldlevel = 0
        vim.cmd('buffer ' .. buf)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        set_commit_keymaps(buf)
end

-- Keymaps for the smartlog buffer.
---@param buf integer
local function set_ssl_keymaps(buf)
        local map = keymapper { buffer = buf, nowait = true, silent = true }

        map('<CR>', function()
                local hash = hash_at_cursor()
                if not hash then return end
                local out, err = run('show', hash, '--git')
                if err then return end
                show_commit(out)
        end, "sl show: Open commit's diff")

        map('g', function() render_smartlog() end, 'Refresh')

        map('d', function()
                local out, err = run('diff', '--git')
                if err then return end
                show_commit(out)
        end, 'sl diff: Show uncommitted changes')

        map('G', function()
                local hash = hash_at_cursor()
                if not hash then return end
                vim.notify('sl goto ' .. hash .. '...', vim.log.levels.INFO)
                local stdout, err = run('goto', hash)
                if err then return end
                render_smartlog()
                vim.notify(stdout, vim.log.levels.INFO)
        end, 'sl goto: Check out commit at cursor')

        map('y', function()
                local hash = hash_at_cursor()
                if not hash then return end
                vim.fn.setreg('+', hash) -- system clipboard
                vim.fn.setreg('"', hash) -- unnamed register
                vim.notify('Copied: ' .. hash, vim.log.levels.INFO)
        end, 'Yank commit hash')

        map('r', function()
                local hash = hash_at_cursor()
                if not hash then return end
                vim.api.nvim_feedkeys(':!' .. M.conf.exec .. ' rebase -s ' .. hash .. ' -d remote/master', 'n', false)
        end, 'sl rebase onto remote/master (prefilled)')

        map('p', function()
                vim.notify('sl pull ...', vim.log.levels.INFO)
                local stdout, err = run 'pull'
                if err then return end
                vim.notify(stdout, vim.log.levels.INFO)
                render_smartlog()
        end, 'sl pull')

        map('a', function() vim.api.nvim_feedkeys(':!' .. M.conf.exec .. ' amend --edit', 'n', false) end, 'sl amend --edit (prefilled)')

        map('s', function()
                local hash = hash_at_cursor()
                if not hash then return end
                vim.api.nvim_feedkeys(':!jf submit -un --publish-when-ready', 'n', false)
        end, 'jf submit (prefilled)')
end

vim.api.nvim_create_user_command('SaplingHistory', function()
        local file = vim.api.nvim_buf_get_name(0)
        if file == '' then
                vim.notify('No file in current buffer', vim.log.levels.WARN)
                return
        end
        local out, err = run('log', '-T', '{node|short}\t{date|isodate}\t{phabdiff}\t{author|user}\t{desc|firstline}\n', '--', file)
        if err then return end
        local entries = {}
        for line in out:gmatch '[^\n]+' do
                local hash, date, diff, author, title = line:match '^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t(.+)$'
                table.insert(entries, {
                        text = string.format('%s %s  %s  %s  %s', hash, date, diff, author, title),
                        -- stash your own data under user_data (Neovim preserves this)
                        user_data = { hash = hash, date = date, diff = diff, author = author, title = title },
                })
        end
        if #entries == 0 then
                vim.notify('No sl history for ' .. file, vim.log.levels.INFO)
                return
        end
        vim.fn.setqflist({}, ' ', { title = 'history', items = entries })
        vim.cmd 'copen'
        -- after :copen the current window is the qf window; map directly on its buffer
        vim.keymap.set('n', '<CR>', function()
                local item = vim.fn.getqflist({ items = 1 }).items[vim.fn.line('.')]
                if not item or not item.user_data then return end
                split_diff_view(file, item.user_data.hash)
        end, { buffer = 0, nowait = true, silent = true })
end, { desc = 'Sapling history (qflist) for current file' })

vim.api.nvim_create_user_command('Sapling', function()
        local buf = render_smartlog()
        if not buf then return end
        set_ssl_keymaps(buf)
        vim.cmd('buffer ' .. buf)
end, { desc = 'Open Sapling smartlog' })

M.diff_foldexpr = diff_foldexpr
return M
