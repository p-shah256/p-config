vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = 'a'
vim.o.undofile = true -- persists it after you close the buffer
vim.o.ignorecase = true -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.smartcase = true
vim.o.cursorline = true
vim.o.confirm = true
vim.o.inccommand = 'split' -- Preview substitutions live, as you type!
vim.o.clipboard = 'unnamedplus' -- Use OSC 52 for clipboard (works over SSH)
vim.o.termguicolors = true
vim.o.updatetime = 300
-- vim.o.autocomplete only supports 'complete' sources (buffer keywords, etc.)
-- LSP can be added via omnifunc ('o' flag) but loses snippet expansion and
-- completionItem/resolve (docs, signature help). So we disable autocomplete
-- on LSP buffers and let vim.lsp.completion handle those instead.
vim.o.autocomplete = true -- default is true for all
vim.o.completeopt = "menu,menuone,popup,noselect"
vim.o.pumheight = 10
vim.opt.foldmethod = 'expr' -- Enable Tree-sitter folding globally
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldlevel = 99 -- Keep folds open by default
vim.cmd('packadd! nvim.undotree')
vim.opt.list = true
vim.opt.listchars = {
	tab = "▏ ",
	leadmultispace = "▏ ",
	trail = "·"
}
-- vim.o.pumborder = 'rounded'
vim.opt.fixendofline = false
