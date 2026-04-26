-- map arrow keys to pane shifts.
vim.keymap.set("n", "<Up>", "<C-w><C-k>", { noremap = true })
vim.keymap.set("n", "<Down>", "<C-w><C-j>", { noremap = true })
vim.keymap.set("n", "<Left>", "<C-w><C-h>", { noremap = true })
vim.keymap.set("n", "<Right>", "<C-w><C-l>", { noremap = true })

-- Prevent { and } paragraph motions from polluting the jumplist
vim.keymap.set("n", "}", ':<C-u>execute "keepjumps norm! " . v:count1 . "}"<CR>', { silent = true })
vim.keymap.set("n", "{", ':<C-u>execute "keepjumps norm! " . v:count1 . "{"<CR>', { silent = true })
vim.keymap.set("v", "}", ':<C-u>execute "keepjumps norm! gv" . v:count1 . "}"<CR>', { silent = true })
vim.keymap.set("v", "{", ':<C-u>execute "keepjumps norm! gv" . v:count1 . "{"<CR>', { silent = true })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

vim.keymap.set("n", "-", function()
	local name = vim.fn.expand("%:t")
	vim.cmd("Ex")
	if name ~= "" then
		vim.fn.search("\\V" .. name, "cw")
	end
end, { desc = "Open netrw" })

-- AUTOPAIRS
local autopairs = { ["("] = ")", ["["] = "]", ["{"] = "}", ['"'] = '"', ["`"] = "`", ["'"] = "'", ["<"] = ">" }
local t = vim.api.nvim_replace_termcodes
local bs_del = t("<BS><Del>", true, false, true)
local bs = t("<BS>", true, false, true)
for open, close in pairs(autopairs) do
	local pair_keys = t(open .. close .. "<Left>", true, false, true)
	vim.keymap.set("i", open, function()
		vim.api.nvim_feedkeys(pair_keys, "n", false)
	end, { noremap = true, silent = true })
end
vim.keymap.set("i", "<BS>", function()
	local line = vim.api.nvim_get_current_line()
	local _, col = unpack(vim.api.nvim_win_get_cursor(0))
	if autopairs[line:sub(col, col)] == line:sub(col + 1, col + 1) then
		vim.api.nvim_feedkeys(bs_del, "n", false)
	else
		vim.api.nvim_feedkeys(bs, "n", false)
	end
end, { noremap = true, silent = true })

vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, { desc = "signature_help while filling in function args" })

vim.keymap.set("n", "<C-j>", "<cmd>keepjumps cnext<CR>")
vim.keymap.set("n", "<C-k>", "<cmd>keepjumps cprev<CR>")

vim.keymap.set("n", "*", function()
	vim.cmd("keepjumps normal! mi*`i")
end, { desc = "Search word under cursor without jumping", noremap = true, silent = true })

-- TODO: not a fan of this, ideally you should be able to surround with anything right?
vim.keymap.set("v", "s", function()
	local char = vim.fn.getcharstr()
	local end_char = char
	local pairs = {
		["("] = ")",
		["["] = "]",
		["{"] = "}",
		["<"] = ">",
	}
	if pairs[char] then
		end_char = pairs[char]
	end
	local keys = vim.api.nvim_replace_termcodes("c" .. char .. end_char .. "<Esc>P", true, false, true)
	vim.api.nvim_feedkeys(keys, "n", false)
end, { desc = "surround selection with a char" })
