vim.pack.add({
	'https://github.com/ibhagwan/fzf-lua',
})
local fzf = require('fzf-lua')
vim.keymap.set({ 'n', 't' }, '<leader><leader>', fzf.buffers, { desc = 'Find in open buffers' })
vim.keymap.set({ 'n', 't' }, '<leader>sf', fzf.files, { desc = 'Find in open buffers' })
vim.keymap.set({ 'n', 't' }, '<leader>sk', fzf.keymaps, { desc = '[s]earch [k]eymaps' })
vim.keymap.set({ 'n', 't' }, '<leader>s.', function() fzf.oldfiles({ cwd_only = true }) end, { desc = '[s]earch [o]ld files (cwd)' })
vim.keymap.set({ 'n', 't' }, '<leader>sg', fzf.grep, { desc = '[s]earch [g]rep' })
vim.keymap.set({ 'n', 't' }, '<leader>sj', fzf.jumps, { desc = '[s]earch [j]umps' })
vim.keymap.set({ 'n', 't' }, '<leader>so', fzf.lsp_document_symbols, { desc = '[s]earch lsp [o]bjects' })
vim.keymap.set({ 'n', 't' }, '<leader>sh', fzf.helptags, { desc = '[s]earch [h]elp tags' })
vim.keymap.set({ 'n', 't' }, '<leader>sm', fzf.helptags, { desc = '[s]earch [m]arks' })
