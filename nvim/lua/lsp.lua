vim.lsp.config["lua_ls"] = {
	-- Command and arguments to start the server.
	cmd = { "lua-language-server" },
	-- Filetypes to automatically attach to.
	filetypes = { "lua" },
	-- Sets the "workspace" to the directory where any of these files is found.
	-- Files that share a root directory will reuse the LSP server connection.
	-- Nested lists indicate equal priority, see |vim.lsp.Config|.
	root_markers = { { ".luarc.json", ".luarc.jsonc" }, ".git" },
	-- Specific settings to send to the server. The schema is server-defined.
	-- Example: https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
			},
			workspace = {
				library = { vim.env.VIMRUNTIME },
			},
		},
	},
}
vim.lsp.enable("lua_ls")

vim.lsp.config["pyrefly"] = {
	cmd = { "pyrefly", "lsp" },
	filetypes = { "python" },
	root_markers = { "pyrefly.toml", "pyproject.toml", ".git" },
}
vim.lsp.enable("pyrefly")

-- FORMATTER
local formatters_by_ft = {
	lua = { "stylua", "-" },
	sh = { vim.fn.expand("~/go/bin/shfmt") },
	bash = { vim.fn.expand("~/go/bin/shfmt") },
	python = { "black", "-" },
}

vim.keymap.set("n", "<leader>f", function()
	-- Prefer CLI formatter if configured for this filetype
	local cmd = formatters_by_ft[vim.bo.filetype]
	if cmd and vim.fn.executable(cmd[1]) == 1 then
		local buf = vim.api.nvim_get_current_buf()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local ilines = table.concat(lines, "\n") .. "\n"
		vim.system(cmd, { stdin = ilines }, function(result)
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
				vim.notify("Formatted with " .. cmd[1]:match("[^/]+$"))
			end)
		end)
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
