local M = {}

-- stdin formatters
M.fmt_ft = {
	lua = { "stylua", "-" },
	sh = { vim.fn.expand("~/go/bin/shfmt") },
	bash = { vim.fn.expand("~/go/bin/shfmt") },
}

-- In-place formatters (modify file directly, then reload)
M.inplace_fmt_ft = {
	-- configerator = { "arc", "f" },
}

-- NEOVIM:
-- crash course on nvim threading/scheduling
-- two loops:
-- A) main loop - check for user input;; run any scheduled callbacks;; redraw screen;; repeat
-- B) libuv with its set of thread pool to do all the work in background.
--
-- When you call vim.system(), libuv spawns a new process with fmtr and monitors the output with its thread.
-- while vim.system() returns immideatly (non blcking).
-- on proc exit, it will trigger the registered callback
--
-- this means that all the editor operations (vim.cmd and vim.api.*) should be run in thread A to avoid race conditions b/w A and B.
-- when the callback fires, we want all the editor ops to run
-- on thread A. vim.schedule will put that work on thread A.

local function inplace_fmt(fmtr)
	if vim.bo.modified then
		vim.cmd("silent write") -- writes silently
	end
	-- don't create surprise writes
	-- but then we loose unwritten changes are formatter will replace the file
	local cmd = vim.list_extend(vim.list_slice(fmtr), { vim.fn.expand("%:p") })
	-- LUA: vim.system runs cmd and returns result object in the callback
	--      allows dealing with the result of the cmd
	vim.system(cmd, {}, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				vim.notify("Formatter failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
				return
			end
			vim.cmd("silent edit!") --reload file
			vim.notify("Formatted with " .. fmtr[1])
		end)
	end)
end

local function stdin_fmt(fmtr)
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local input = table.concat(lines, "\n") .. "\n"
	vim.system(fmtr, { stdin = input }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				vim.notify("Formatter failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
				return
			end
			local formatted = vim.split(result.stdout, "\n")
			if formatted[#formatted] == "" then
				formatted[#formatted] = nil
			end
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted)
			vim.notify("Formatted with " .. fmtr[1]:match("[^/]+$"))
		end)
	end)
end

vim.keymap.set("n", "<leader>f", function()
	local fmtr = M.inplace_fmt_ft[vim.bo.filetype]
	local stdin_fmtr = M.fmt_ft[vim.bo.filetype]
	if fmtr then
		inplace_fmt(fmtr)
		return
	elseif stdin_fmtr then
		stdin_fmt(stdin_fmtr)
		return
	end

	-- Fall back to LSP formatting
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	for _, client in ipairs(clients) do
		if client:supports_method("textDocument/formatting") then
			vim.notify("Formatting with " .. client.name)
			vim.lsp.buf.format({ async = true, name = client.name })
			return
		end
	end
	vim.notify("No formatter for " .. vim.bo.filetype, vim.log.levels.WARN)
end, { desc = "[f]ormat buffer" })

return M
