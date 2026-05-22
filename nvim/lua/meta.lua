-- just overwrite a bunch of functions and create some commands if
-- in sapling repository
local root = vim.fn.systemlist("sl root 2>/dev/null")[1] or ""
if root == "" then
	return
end

vim.api.nvim_create_user_command("Qf", function(opts)
	local cmd = opts.args
	local lines = vim.fn.systemlist(cmd)

	if cmd:match("^myles%s") then
		local items = {}
		for _, line in ipairs(lines) do
			if line ~= "" then
				table.insert(items, { filename = root .. "/" .. line })
			end
		end
		vim.fn.setqflist({}, "r", { title = cmd, items = items })
	else
		for i, line in ipairs(lines) do
			lines[i] = line:gsub("^fbsource/", root .. "/")
		end
		vim.fn.setqflist({}, "r", { title = cmd, lines = lines, efm = "%f:%l:%c:%m,%f:%l:%m" })
	end
	vim.cmd("botright copen")
end, { nargs = "+" })

vim.keymap.set("n", "<leader>sf", ":Qf myles --list -n 50 ", { desc = "Search files (myles)" })
vim.keymap.set("n", "<leader>sg", ":Qf zbgr ", { desc = "[s]earch [g]rep" })
-- TODO: in visual mode, just sg for the selected part

-- TODO: eventually we would like to remove this plugin?
vim.pack.add({ "https://github.com/neovim/nvim-lspconfig" })
vim.opt.rtp:prepend("/usr/share/fb-editor-support/nvim")
vim.lsp.enable({
	-- 'pyrefly',            -- Pyrefly type checker
	"rust-analyzer@meta", -- Rust - Run :RustAnalyzerReload on TARGETS changes
	"fb-pyright-ls@meta", -- Python
	"pyre@meta", -- Python type checking
	"thriftlsp@meta", -- Thrift
	"cppls@meta", -- C++
	"buckls@meta", -- Buck
	"buck2@meta", -- Buck/Starlark
	"gopls@meta", -- Golang
	"flow@meta", -- JavaScript/Flow
	"hhvm", -- Hack
	"linttool@meta", -- Linting and formatting
})
function VCS_DIFF_FILE(file)
	-- insert mode: diff against working-copy parent (uncommitted changes only)
	-- normal mode: diff against parent commit (committed + uncommitted)
	local rev = vim.api.nvim_get_mode().mode:sub(1, 1) == "i" and "." or ".^"
	return { "sl", "cat", "-r", rev, file }
end
function VCS_DIFF_FILES()
	return { "sl", "status" }
end
function VCS_HUNKS()
	return { "sl", "diff", "-U0" } -- adding '--change .' would give committed changes
end

-- configerator shouls use python parsers, decorators, folds, etc
vim.treesitter.language.register("python", "configerator")

-- overrides
local fmt = require("format")
fmt.inplace_fmt_ft.configerator = { "arc", "f" }
vim.lsp.enable("clangd", false)
