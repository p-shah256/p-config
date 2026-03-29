-- Cursor-aware indent guides: active level highlighted, others dimmed.
local M = {}
local ns = vim.api.nvim_create_namespace('indent_guides')

local function redraw(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= '' then return end

  local sw = vim.bo[bufnr].shiftwidth
  if sw == 0 then sw = vim.bo[bufnr].tabstop end
  if sw < 1 then sw = 4 end

  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local cline = vim.api.nvim_buf_get_lines(bufnr, crow - 1, crow, false)[1] or ''
  local cindent = #cline:match('^%s*')
  local active_level = math.floor((cline:find('%S') and cindent or ccol) / sw)

  local top = vim.fn.line('w0') - 1
  local bot = vim.fn.line('w$')
  vim.api.nvim_buf_clear_namespace(bufnr, ns, top, bot)

  for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, top, bot, false)) do
    local indent = #line:match('^%s*')
    if line:find('%S') then
      for level = 1, math.floor(indent / sw) do
        vim.api.nvim_buf_set_extmark(bufnr, ns, top + i - 1, (level - 1) * sw, {
          virt_text = { { '│', level == active_level and 'IndentGuideActive' or 'IndentGuide' } },
          virt_text_pos = 'overlay',
          priority = 1,
        })
      end
    end
  end
end

function M.setup()
  local function set_highlights()
    local active = vim.api.nvim_get_hl(0, { name = 'Function', link = false })
    local dim = vim.api.nvim_get_hl(0, { name = 'Whitespace', link = false })
    if not dim.fg then dim = vim.api.nvim_get_hl(0, { name = 'NonText', link = false }) end
    vim.api.nvim_set_hl(0, 'IndentGuideActive', { fg = active.fg, nocombine = true })
    vim.api.nvim_set_hl(0, 'IndentGuide', { fg = dim.fg, nocombine = true })
  end

  set_highlights()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('IndentGuideColors', { clear = true }),
    callback = set_highlights,
  })

  vim.api.nvim_create_autocmd(
    { 'CursorMoved', 'CursorMovedI', 'BufEnter', 'BufWinEnter', 'WinScrolled', 'TextChanged', 'TextChangedI' },
    { group = vim.api.nvim_create_augroup('CustomIndentGuides', { clear = true }),
      callback = function(ev) redraw(ev.buf) end }
  )
end

return M
