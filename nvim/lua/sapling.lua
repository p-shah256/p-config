-- sapling.lua — Smartlog-first Sapling UI for Neovim
-- Usage: require('sapling').open()  or  :lua require('sapling').open()
--
-- The basic idea mirrors the Emacs version:
--   1. Dump `sl ssl` output into a buffer
--   2. For every operation, parse the hash on the cursor line and pass it to sl

-- I could make this agnostic to VC, like make it work with git, but git uses a diff model
-- (stage, unstage, commit etc) so its best to limit this to sapling
-- vim fugitive does all the work for git anyway
local M = {}
M.conf = {
	exec = "sl",
}

-- helpers
local function find_repo_root()
	-- Walk up from cwd looking for a .sl directory
	local dir = vim.fn.getcwd()
	while dir ~= "/" do
		if vim.fn.isdirectory(dir .. "/.sl") == 1 then
			return dir
		end
		dir = vim.fn.fnamemodify(dir, ":h")
	end
	return vim.fn.getcwd()
end

local function run(...)
	local args = { ... }
	local cmd = { M.conf.exec } -- create it, keep a reference
	vim.list_extend(cmd, args) -- extend it in place
	local root = find_repo_root()
	local result = vim.system(cmd, { cwd = root, text = true }):wait()
	return result.stdout or ""
end

local function get_or_create_buf(name)
	local existing = vim.fn.bufnr(name)
	if existing ~= -1 then
		return existing
	end
	local buf = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
	vim.api.nvim_buf_set_name(buf, name)
	return buf
end

local function diff_foldexpr(lnum)
	local line = vim.fn.getline(lnum)
	if line:match("^diff %-%-git") then
		return ">1" -- file level, depth 1
	end
	if line:match("^@@") then
		return ">2" -- hunk level, depth 2
	end
	return "=" -- same as previous line
end

-- main sapling starts here
local SAPLING_BUF = "*sapling*"
local DIFF_BUF = "*sapling-diff*"
local function render_smartlog()
	local buf = get_or_create_buf(SAPLING_BUF)
	local ssl_output = run("ssl")
	local ssl_lines = vim.split(ssl_output, "\n", { plain = true }) -- why do we need this?
	-- Remove trailing empty line that systemlist often appends
	if ssl_lines[#ssl_lines] == "" then
		table.remove(ssl_lines)
	end
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, ssl_lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
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
local function hash_at_cursor()
	local line = vim.api.nvim_get_current_line()
	--   .*?[@ox+]   — any graph art, then node symbol
	--   %s+         — whitespace
	--   ([0-9a-f]+) — hex hash (capture)
	local hash = line:match("[@ox+]%s+([0-9a-f]+)")
	if not hash then
		vim.notify("No commit hash on this line", vim.log.levels.WARN)
		return
	end
	return hash
end

local function split_diff_view(fpath)
	local root = find_repo_root()
	local function get_hash_from_diff_buf()
		local lines = vim.api.nvim_buf_get_lines(0, 0, 5, false)
		for _, line in ipairs(lines) do
			local hash = line:match("^changeset:%s+(%x+)")
			if hash then
				return hash
			end
		end
	end
	local function cat(rev)
		local cmd = { M.conf.exec, "cat", "-r", rev, fpath }
		local res = vim.system(cmd, { cwd = root, text = true }):wait()
		return vim.split(res.stdout or "", "\n", { plain = true })
	end
	local function make_diff_buf(lines, name)
		-- wipe existing as tabclose does not close the buffers
		local existing = vim.fn.bufnr(name)
		if existing ~= -1 then
			vim.api.nvim_buf_delete(existing, { force = true })
		end
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, name)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "swapfile", false)
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		local ext = fpath:match("%.(%w+)$")
		if ext then
			vim.api.nvim_buf_set_option(buf, "filetype", ext)
		end
		return buf
	end
	local c_hash = get_hash_from_diff_buf()
	if not c_hash then
		vim.notify("Can't find changeset hash in buffer", vim.log.levels.WARN)
		return
	end
	local old_buf = make_diff_buf(cat(c_hash .. "^"), "sapling-old://" .. fpath)
	local new_buf = make_diff_buf(cat(c_hash), "sapling-new://" .. fpath)
	vim.cmd("tabnew") -- open a new tab so closing it brings you straight back, no cleanup needed
	vim.api.nvim_win_set_buf(0, old_buf)
	vim.cmd("diffthis")
	vim.cmd("vsplit")
	vim.api.nvim_win_set_buf(0, new_buf)
	vim.cmd("diffthis")
end

-- DIFF VIEW — display diff output in *sapling-diff* buffer
-- this is the heart of each diff view
local function display_diff(output)
	if vim.trim(output) == "" then
		vim.notify("No changes to show", vim.log.levels.INFO)
		return
	end
	local buf = get_or_create_buf(DIFF_BUF)
	local lines = vim.split(output, "\n", { plain = true })
	if lines[#lines] == "" then
		table.remove(lines)
	end
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "diff")
	vim.wo.foldmethod = "expr"
	vim.wo.foldexpr = "v:lua.require('sapling').diff_foldexpr(v:lnum)"
	vim.wo.foldlevel = 1
	-- Keymaps for the diff buffer
	local opts = { buffer = buf, silent = true }
	vim.keymap.set("n", "q", function()
		vim.cmd("buffer " .. vim.fn.bufnr(SAPLING_BUF))
	end, opts)
	-- Show in current window (sapling window), same as Emacs switch-to-buffer
	vim.cmd("buffer " .. buf)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	-- diff split
	vim.keymap.set("n", "D", function()
		local line = vim.api.nvim_get_current_line()
		local fpath = line:match("^diff %-%-git a/.+ b/(.+)")
		if not fpath then
			vim.notify("cursor must be on a 'diff --git' line", vim.log.levels.WARN)
			return
		end
		split_diff_view(fpath)
	end, { buffer = buf, silent = true })
end

local function set_keymaps(buf)
	vim.keymap.set("n", "<CR>", function()
		local hash = hash_at_cursor()
		if not hash then
			return
		end -- autoformatter fucks this up i like concise
		display_diff(run("show", hash, "--git"))
	end, { desc = "sl show: Open commit's diff", buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "g", function()
		render_smartlog()
	end, { desc = "Refresh", buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "d", function()
		display_diff(run("diff", "--git")) -- fix
	end, { desc = "sl diff: Show uncommitted changes", buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "G", function()
		local hash = hash_at_cursor()
		if not hash then
			return
		end
		vim.notify("sl goto " .. hash .. "...", vim.log.levels.INFO)
		run("goto", hash)
		render_smartlog()
		vim.notify("Now at " .. hash, vim.log.levels.INFO)
	end, { desc = "sl goto: Checkout commit <hash>", buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "y", function()
		local hash = hash_at_cursor()
		if not hash then
			vim.notify("No commit hash found on this line", vim.log.levels.WARN)
			return
		end
		vim.fn.setreg("+", hash) -- system clipboard
		vim.fn.setreg('"', hash) -- unnamed register
		vim.notify("Copied: " .. hash, vim.log.levels.INFO)
	end, { desc = "Yank commit under cursor", buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "a", function()
		run("amend")
		vim.notify("Amended changes to current checkout", vim.log.levels.INFO)
		render_smartlog()
	end, { desc = "sl amend: amend uncommitted changes to current commit", buffer = buf, nowait = true, silent = true })
end

vim.api.nvim_create_user_command("Sapling", function()
	local buf = render_smartlog()
	set_keymaps(buf)
	vim.cmd("buffer " .. buf)
end, { desc = "Open Sapling smartlog" })
M.diff_foldexpr = diff_foldexpr
return M
