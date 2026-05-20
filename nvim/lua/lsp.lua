vim.lsp.config["lua_ls"] = {
	cmd = { "lua-language-server" }, -- Command and arguments to start the server.
	filetypes = { "lua" }, -- Filetypes to automatically attach to.
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

vim.lsp.config["clangd"] = {
	cmd = { "clangd" },
	filetypes = { "c", "cpp" },
	root_markers = { "compile_commands.json", "compile_flags.txt", ".git" },
}
vim.lsp.enable("clangd")

vim.lsp.config["superhtml"] = {
	cmd = { "superhtml", "lsp" },
	filetypes = { "html" },
	root_markers = { ".git" },
}
vim.lsp.enable("superhtml")
