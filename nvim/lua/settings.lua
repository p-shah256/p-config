vim.keymap.set('n', '*', function()
  vim.cmd 'keepjumps normal! mi*`i'
end, { desc = 'Search word under cursor without jumping', noremap = true, silent = true })

-- map arrow keys to pane shifts.
vim.keymap.set('n', '<Up>', '<C-w><C-k>', { noremap = true })
vim.keymap.set('n', '<Down>', '<C-w><C-j>', { noremap = true })
vim.keymap.set('n', '<Left>', '<C-w><C-h>', { noremap = true })
vim.keymap.set('n', '<Right>', '<C-w><C-l>', { noremap = true })

-- Prevent { and } paragraph motions from polluting the jumplist
vim.keymap.set('n', '}', ':<C-u>execute "keepjumps norm! " . v:count1 . "}"<CR>', { silent = true })
vim.keymap.set('n', '{', ':<C-u>execute "keepjumps norm! " . v:count1 . "{"<CR>', { silent = true })
vim.keymap.set('v', '}', ':<C-u>execute "keepjumps norm! gv" . v:count1 . "}"<CR>', { silent = true })
vim.keymap.set('v', '{', ':<C-u>execute "keepjumps norm! gv" . v:count1 . "{"<CR>', { silent = true })

vim.o.termguicolors = true

-- minimize command line space usage
vim.o.cmdheight = 0
vim.o.showcmd = false

-- Increase oldfiles history to 100
vim.opt.shada = { "'100", '<50', 's10', 'h' }

-- Enable folding with treesitter
vim.o.foldmethod = 'expr'
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.o.foldlevel = 99 -- Open all folds by default
vim.o.foldlevelstart = 99 -- Open all folds when opening a fi
vim.o.foldenable = true
vim.o.foldopen = '' -- Don't automatically open folds when ju

-- Custom fold text to show just the first line
vim.o.foldtext = ''
vim.o.fillchars = 'fold: '

-- Auto-start treesitter highlighting for all buffers
vim.api.nvim_create_autocmd({ 'FileType', 'BufEnter' }, {
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    -- Check if treesitter parser exists for this filetype
    local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    if lang and pcall(vim.treesitter.language.add, lang) then
      pcall(vim.treesitter.start, bufnr)
    end
  end,
})

vim.api.nvim_create_user_command('CopyPath', function(opts)
  local path = vim.fn.expand '%:p'
  if path:match '^oil://' then
    path = path:gsub('^oil://', '')
    local cwd = vim.fn.getcwd()
    if not cwd:match '/$' then
      cwd = cwd .. '/'
    end
    path = path:gsub('^' .. vim.pesc(cwd), '')
  end
  -- Use the range if provided, otherwise check visual selection marks
  local start_line, end_line
  if opts.range > 0 then
    start_line = opts.line1
    end_line = opts.line2
  else
    -- Check if there's a visual selection
    local start_pos = vim.fn.getpos "'<"
    local end_pos = vim.fn.getpos "'>"
    start_line = start_pos[2]
    end_line = end_pos[2]
    -- Only use selection if it's valid and in current buffer
    local current_buf = vim.api.nvim_get_current_buf()
    local selection_buf = start_pos[1]
    if not (selection_buf == current_buf and start_line > 0 and end_line > 0 and start_line <= end_line) then
      start_line = nil
      end_line = nil
    end
  end
  if start_line and end_line then
    if start_line == end_line then
      path = path .. ':' .. start_line
    else
      path = path .. ':' .. start_line .. '-' .. end_line
    end
  end
  require('osc52').copy(path)
end, { range = true })
vim.keymap.set('n', '<leader>cp', '<cmd>CopyPath<cr>', { desc = 'Copy Path' })
vim.keymap.set('v', '<leader>cp', ':CopyPath<cr>', { desc = 'Copy Path' })

-- .txt file settings: folding and section navigation
local txt_group = vim.api.nvim_create_augroup('txtfiles', { clear = true })
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile', 'BufEnter' }, {
  group = txt_group,
  pattern = '*.txt',
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.foldmethod = 'expr'
    vim.opt_local.foldexpr = "getline(v:lnum)=~'^='?'>1':'='"
    vim.opt_local.foldenable = true
    vim.opt_local.foldopen = ''
    vim.opt_local.foldlevel = 99
    vim.opt_local.foldlevelstart = 99
    vim.opt_local.foldtext = [[substitute(getline(v:foldstart+1),'\s*\*.*\*\s*','','')]]
    vim.keymap.set('n', ']]', '/^===<CR>:noh<CR>', { buffer = true, silent = true })
    vim.keymap.set('n', '[[', '?^===<CR>:noh<CR>', { buffer = true, silent = true })
  end,
})

-- Help file enhancements: folding and section navigation
local help_group = vim.api.nvim_create_augroup('helpfiles', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = help_group,
  pattern = 'help',
  callback = function()
    vim.opt_local.foldmethod = 'expr'
    vim.opt_local.foldexpr = "getline(v:lnum)=~'^='?'>1':'='"
    vim.opt_local.foldenable = true
    vim.opt_local.foldopen = ''
    vim.opt_local.foldlevel = 0
    vim.opt_local.foldtext = [[substitute(getline(v:foldstart+1),'\s*\*.*\*\s*','','')]]
    vim.keymap.set('n', ']]', '/^===<CR>:noh<CR>', { buffer = true, silent = true })
    vim.keymap.set('n', '[[', '?^===<CR>:noh<CR>', { buffer = true, silent = true })
  end,
})
