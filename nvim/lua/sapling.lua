-- The basic idea mirrors the Emacs version:
--   1. Dump `sl ssl` output into a buffer
--   2. For every operation, parse the hash on the cursor line and pass it to sl

-- I could make this agnostic to VC, like make it work with git, but git uses a diff working model
-- (stage, unstage, commit etc) so its best to limit this to sapling
-- vim fugitive does all the work for git anyway

-- The basic idea mirrors the Emacs version:
--   1. Dump `sl ssl` output into a buffer.
--   2. Parse the hash on the cursor line and pass it to Sapling operations.
--
-- This intentionally supports only Sapling. Git's staging model is different,
-- and Fugitive already provides a complete Git workflow.

local M = {
        conf = { exec = "sl" },
}

local SMARTLOG_BUF = "*sapling*"
local COMMIT_BUF = "*sapling-commit*"

-- ////////////////////////////////////////////////////////////////////////////////
-- HELPERS START
local function repo_root() return vim.fs.root(vim.fn.getcwd(), { ".hg", ".sl" }) or vim.fn.getcwd() end
local function strip_ansi(line) return line:gsub("\27%[[0-9;]*m", "") end

-- Run Sapling from the repository root and report failures.
local function sl(...)
        local cmd = { M.conf.exec, ... }
        local result = vim.system(cmd, { cwd = repo_root(), text = true }):wait()
        if result.code ~= 0 then
                vim.notify(table.concat(cmd, " ") .. "\nfailed with exit code " .. result.code .. "\n" .. (result.stderr or ""), vim.log.levels.ERROR)
                return nil
        end
        return result.stdout or ""
end

-- Own the lifecycle, presentation, and mappings of a reusable scratch view.
local function open_view(spec)
        local buf = vim.fn.bufnr(spec.name)
        if spec.ansi and buf ~= -1 then -- term buffers cannot be rewritten normally, so recreate on refresh
                vim.api.nvim_buf_delete(buf, { force = true })
                buf = -1
        end
        if buf == -1 then
                buf = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_buf_set_name(buf, spec.name)
        end
        assert(not (spec.ansi and spec.editable))
        if spec.ansi then
                local channel = vim.api.nvim_open_term(buf, {})
                local output = (spec.text or ""):gsub("\n", "\r\n")
                vim.api.nvim_chan_send(channel, output)
        else
                local lines = spec.lines or vim.split(spec.text or "", "\n", { plain = true })
                if lines[#lines] == "" then table.remove(lines) end
                vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
                vim.api.nvim_set_option_value("modified", false, { buf = buf })

                if spec.editable then
                        vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
                        local group = vim.api.nvim_create_augroup("SaplingWrite" .. buf, { clear = true })
                        vim.api.nvim_create_autocmd("BufWriteCmd", {
                                group = group,
                                buffer = buf,
                                callback = function()
                                        local contents = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                                        if spec.on_write(contents) then vim.api.nvim_set_option_value("modified", false, { buf = buf }) end
                                end,
                        })
                else
                        vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
                        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
                end
        end
        if spec.filetype then vim.api.nvim_set_option_value("filetype", spec.filetype, { buf = buf }) end
        for _, mapping in ipairs(spec.mappings or {}) do
                vim.keymap.set("n", mapping[1], mapping[2], {
                        buffer = buf,
                        silent = true,
                        nowait = true,
                        desc = mapping[3],
                })
        end
        if spec.enter ~= false then
                vim.api.nvim_win_set_buf(0, buf)
                for option, value in pairs(spec.window_options or {}) do
                        vim.api.nvim_set_option_value(option, value, { win = 0 })
                end
                if spec.cursor then vim.api.nvim_win_set_cursor(0, spec.cursor) end
        end
        return buf
end

local function hash_at_cursor()
        -- Smartlog lines look like:
        --   @  c2089707d8  Today at 13:37  shah  origin/master
        --   o  93b55ca2d1  Apr 20          shah
        -- The hash is the first token after a node symbol.
        local hash = vim.api.nvim_get_current_line():match("[@ox+]%s+([0-9a-f]+)")
        if not hash then vim.notify("No commit hash on this line", vim.log.levels.WARN) end
        return hash
end

local function file_at_cursor()
        local relative = vim.api.nvim_get_current_line():match("^diff %-%-git a/.+ b/(.+)")
        if not relative then
                vim.notify("Cursor must be on a 'diff --git' line", vim.log.levels.WARN)
                return nil
        end
        return repo_root() .. "/" .. relative
end

function M.diff_foldexpr(line_number)
        local line = vim.fn.getline(line_number)
        -- Each changed file is a top-level fold.
        return line:match("^diff %-%-git") and ">1" or "="
end

-- HELPERS END
-- ////////////////////////////////////////////////////////////////////////////////

-- Compare a file across a commit boundary or against the working copy.
local function open_split_diff(path, hash)
        local function revision_lines(revision)
                local result = vim.system({ M.conf.exec, "cat", "-r", revision, path }, { cwd = repo_root(), text = true }):wait()
                if result.code ~= 0 then return {} end

                local lines = vim.split(result.stdout or "", "\n", { plain = true })
                if lines[#lines] == "" then table.remove(lines) end
                return lines
        end
        local old_lines = revision_lines(hash and hash .. "^" or ".")
        -- For uncommitted changes, the new side comes directly from disk.
        local new_lines = hash and revision_lines(hash) or (vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {})
        local filetype = vim.filetype.match({ filename = path })
        local close_mapping = {
                "q",
                function() vim.cmd.tabclose() end,
                "Sapling: close diff tab",
        }

        local old_buf = open_view({
                name = "sapling-old://" .. path,
                lines = old_lines,
                filetype = filetype,
                mappings = { close_mapping },
                enter = false,
        })
        local new_buf = open_view({
                name = "sapling-new://" .. path,
                lines = new_lines,
                filetype = filetype,
                mappings = { close_mapping },
                enter = false,
        })
        vim.cmd.tabnew() -- Use a tab so closing it returns directly to the originating view.
        vim.api.nvim_win_set_buf(0, old_buf)
        vim.cmd.diffthis()
        vim.cmd.vsplit()
        vim.api.nvim_win_set_buf(0, new_buf)
        vim.cmd.diffthis()
end

-- Show either a committed change or the current working-copy diff.
local function open_commit(hash)
        local output = hash and sl("show", hash, "--git") or sl("diff", "--git")
        if not output or vim.trim(output) == "" then
                vim.notify("No changes to show", vim.log.levels.INFO)
                return
        end
        open_view({
                name = COMMIT_BUF,
                text = output,
                filetype = "diff",
                cursor = { 1, 0 },
                window_options = {
                        foldmethod = "expr",
                        foldexpr = "v:lua.require('sapling').diff_foldexpr(v:lnum)",
                        foldlevel = 0,
                },
                mappings = {
                        {
                                "q",
                                function()
                                        local smartlog = vim.fn.bufnr(SMARTLOG_BUF)
                                        if smartlog ~= -1 then vim.api.nvim_win_set_buf(0, smartlog) end
                                end,
                                "Sapling: back to smartlog",
                        },
                        {
                                "<CR>",
                                function()
                                        local path = file_at_cursor()
                                        if path then vim.cmd.edit(vim.fn.fnameescape(path)) end
                                end,
                                "Sapling: open file",
                        },
                        {
                                "D",
                                function()
                                        local path = file_at_cursor()
                                        if path then open_split_diff(path, hash) end
                                end,
                                "Sapling: open split diff",
                        },
                        -- Cycle through changed files and hunks without wrapping.
                        { "]c", function() vim.fn.search("^@@", "W") end, "Sapling: next hunk" },
                        { "[c", function() vim.fn.search("^@@", "bW") end, "Sapling: previous hunk" },
                        { "]]", function() vim.fn.search("^diff --git", "W") end, "Sapling: next file" },
                        { "[[", function() vim.fn.search("^diff --git", "bW") end, "Sapling: previous file" },
                },
        })
end

-- Edit a new or existing commit message; writing the buffer performs the operation.
local function open_message_editor(hash)
        local original = hash and sl("log", "-r", hash, "-T", "{desc}", "--limit", "1") or sl("debugcommitmessage")
        if not original then return end

        local required_diff_line = original:match("Differential Revision:[^\n]+")
        open_view({
                name = "sapling-message://" .. (hash or "new"),
                text = original,
                editable = true,
                filetype = "gitcommit",
                on_write = function(lines)
                        local message = table.concat(lines, "\n")
                        if required_diff_line and not message:find("Differential Revision:", 1, true) then
                                vim.notify("Differential Revision line must be preserved", vim.log.levels.ERROR)
                                return false
                        end

                        local logfile = vim.fn.tempname()
                        vim.fn.writefile(lines, logfile)
                        local output = hash and sl("amend", "--to", hash, "--logfile", logfile) or sl("commit", "--logfile", logfile)
                        vim.fn.delete(logfile)
                        if output == nil then return false end

                        vim.notify(hash and "Commit amended" or "Commit created", vim.log.levels.INFO)
                        vim.schedule(function() vim.cmd.Sapling() end)
                        return true
                end,
                mappings = {
                        { "<C-s>", "<cmd>write<CR>", "Sapling: save commit message" },
                        { "q", "<cmd>confirm bdelete<CR>", "Sapling: close message" },
                },
        })
end

-- Show the smartlog and expose stack operations on the selected commit.
local function open_smartlog()
        local smartlog = sl("ssl", "--color=always")
        -- 1. parse @ so that we can put working copy ON TOP of current commit
        if smartlog == nil then return end
        local ssl_lines = vim.split(smartlog, "\n", { plain = true })
        local curr_line
        local graph_prefix
        for index, line in ipairs(ssl_lines) do
                local visible = strip_ansi(line)
                local at_position = visible:find("@%s+[0-9a-f]+")
                if at_position then -- Match the current node followed by its commit hash.
                        curr_line = index
                        graph_prefix = visible:sub(1, at_position - 1)
                        break
                end
        end
        assert(curr_line and graph_prefix, "Could not find the current commit in smartlog")
        -- 2. get and build the working copy if any
        local status = sl("status", "--color=always")
        local working = { graph_prefix .. "\27[1;33m@@ Working Copy\27[0m" }
        if status and vim.trim(status) ~= "" then
                for _, line in ipairs(vim.split(status, "\n", { plain = true, trimempty = true })) do
                        table.insert(working, graph_prefix .. "│  " .. line)
                end
        else
                table.insert(working, graph_prefix .. "│  clean")
        end
        table.insert(working, graph_prefix .. "│")
        -- 3. insert at reverse order
        for index = #working, 1, -1 do
                table.insert(ssl_lines, curr_line, working[index])
        end
        local ssl_output = table.concat(ssl_lines, "\n")

        open_view({
                name = SMARTLOG_BUF,
                text = ssl_output,
                ansi = true,
                mappings = {
                        {
                                "<CR>",
                                function()
                                        local hash = hash_at_cursor()
                                        if hash then open_commit(hash) end
                                end,
                                "Sapling: open commit",
                        },
                        { "g", open_smartlog, "Sapling: refresh" },
                        { "d", function() open_commit(nil) end, "Sapling: show working-copy diff" },
                        {
                                "G",
                                function()
                                        local hash = hash_at_cursor()
                                        if not hash then return end
                                        local output = sl("goto", hash)
                                        if output then
                                                open_smartlog()
                                                vim.notify(output, vim.log.levels.INFO)
                                        end
                                end,
                                "Sapling: go to commit",
                        },
                        {
                                "y",
                                function()
                                        local hash = hash_at_cursor()
                                        if not hash then return end
                                        vim.fn.setreg("+", hash)
                                        vim.fn.setreg('"', hash)
                                        vim.notify("Copied: " .. hash, vim.log.levels.INFO)
                                end,
                                "Sapling: yank commit hash",
                        },
                        {
                                "r",
                                function()
                                        local hash = hash_at_cursor()
                                        if hash then vim.api.nvim_feedkeys(":!" .. M.conf.exec .. " rebase -s " .. hash .. " -d remote/master", "n", false) end
                                end,
                                "Sapling: rebase onto remote/master",
                        },
                        {
                                "p",
                                function()
                                        local output = sl("pull")
                                        if output then
                                                vim.notify(output, vim.log.levels.INFO)
                                                open_smartlog()
                                        end
                                end,
                                "Sapling: pull",
                        },
                        {
                                "a",
                                function()
                                        local hash = hash_at_cursor()
                                        if hash then open_message_editor(hash) end
                                end,
                                "Sapling: amend changes and commit message",
                        },
                        {
                                "c",
                                function() open_message_editor(nil) end,
                                "Sapling: commit working changes",
                        },
                        {
                                "s",
                                function()
                                        if hash_at_cursor() then vim.api.nvim_feedkeys(":!jf submit -un --publish-when-ready", "n", false) end
                                end,
                                "Sapling: submit stack",
                        },
                },
        })
end

-- Populate the quickfix list with the current file's revision history.
local function open_history()
        local file = vim.api.nvim_buf_get_name(0)
        if file == "" then
                vim.notify("No file in current buffer", vim.log.levels.WARN)
                return
        end
        local output = sl("log", "-T", "{node|short}\t{date|isodate}\t{phabdiff}\t{author|user}\t{desc|firstline}\n", "--", file)
        if not output then return end
        local entries = {}
        for line in output:gmatch("[^\n]+") do
                local hash, date, diff, author, title = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t(.+)$")
                table.insert(entries, {
                        text = string.format("%s %s  %s  %s  %s", hash, date, diff, author, title),
                        -- Quickfix preserves arbitrary metadata under user_data.
                        user_data = { hash = hash },
                })
        end
        if #entries == 0 then
                vim.notify("No Sapling history for " .. file, vim.log.levels.INFO)
                return
        end
        vim.fn.setqflist({}, " ", { title = "history", items = entries })
        vim.cmd.copen()
        -- After :copen, the current window is the quickfix window.
        vim.keymap.set("n", "<CR>", function()
                local items = vim.fn.getqflist({ items = 1 }).items
                local item = items[vim.fn.line(".")]
                if item and item.user_data then open_split_diff(file, item.user_data.hash) end
        end, {
                buffer = 0,
                silent = true,
                nowait = true,
                desc = "Sapling: open historical diff",
        })
end

vim.api.nvim_create_user_command("Sapling", open_smartlog, {
        desc = "Open Sapling smartlog",
})

vim.api.nvim_create_user_command("SaplingHistory", open_history, {
        desc = "Show history for current file",
})

-- Future ideas:
--   * Show uncommitted changes above the smartlog.
--   * Wire commit-message editing to the appropriate Sapling commands.

return M
