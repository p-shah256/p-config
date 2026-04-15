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

-- TODO: if a pair is back to back, delete should delete both
-- if next to a word, add only one
vim.keymap.set("i", "(", "(" .. ")" .. "<Left>", { noremap = true, silent = true })
vim.keymap.set("i", "[", "[" .. "]" .. "<Left>", { noremap = true, silent = true })
vim.keymap.set("i", "{", "{" .. "}" .. "<Left>", { noremap = true, silent = true })
vim.keymap.set("i", '"', '"' .. '"' .. "<Left>", { noremap = true, silent = true })
vim.keymap.set("i", "`", "`" .. "`" .. "<Left>", { noremap = true, silent = true })
vim.keymap.set("i", "'", "'" .. "'" .. "<Left>", { noremap = true, silent = true })

vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, { desc = "signature_help while filling in function args" })

vim.keymap.set("n", "<C-j>", "<cmd>keepjumps cnext<CR>")
vim.keymap.set("n", "<C-k>", "<cmd>keepjumps cprev<CR>")

vim.keymap.set('n', '*', function()
  vim.cmd 'keepjumps normal! mi*`i'
end, { desc = 'Search word under cursor without jumping', noremap = true, silent = true })


