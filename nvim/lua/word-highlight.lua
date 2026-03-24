-- Lightweight word-under-cursor highlighting (replaces vim-illuminate).
--
-- Two layers:
--   1. LSP: uses built-in document_highlight (setup via LspAttach in init.lua)
--   2. Regex fallback: for buffers without LSP, highlights <cword> matches
--
-- LSP buffers set vim.b.lsp_highlight = true so the regex layer skips them.

local M = {}

local ns = vim.api.nvim_create_namespace 'word_highlight'
local timer = vim.uv.new_timer()

-- Remove all our highlights from a buffer
local function clear(buf)
  pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
end

-- Find and highlight all matches of the word under cursor (regex fallback)
local function highlight_word()
  local buf = vim.api.nvim_get_current_buf()
  clear(buf)

  -- Skip if LSP is handling highlights for this buffer
  if vim.b[buf].lsp_highlight then return end

  -- Skip large files for performance
  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count > 5000 then return end

  -- Get word under cursor, skip if too short or all punctuation
  local word = vim.fn.expand '<cword>'
  if word == '' or #word < 2 or word:match '^%W+$' then return end

  -- Build a pattern with word boundaries:
  --   %f[%w] = transition into a word char (start boundary)
  --   %f[%W] = transition into a non-word char (end boundary)
  local pattern = '%f[%w]' .. vim.pesc(word) .. '%f[%W]'

  -- Only scan +-200 lines around cursor (not the whole file)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local top = math.max(0, cursor_line - 200)
  local bot = math.min(line_count, cursor_line + 200)
  local lines = vim.api.nvim_buf_get_lines(buf, top, bot, false)

  for i, line in ipairs(lines) do
    local start = 1
    while true do
      local s, e = line:find(pattern, start)
      if not s then break end
      -- Place an extmark highlight on each match
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, top + i - 1, s - 1, {
        end_col = e, hl_group = 'LspReferenceText',
      })
      start = e + 1
    end
  end
end

function M.setup()
  -- On CursorHold: wait 50ms then highlight (debounce rapid cursor stops)
  vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
    callback = function()
      timer:stop()
      timer:start(50, 0, vim.schedule_wrap(highlight_word))
    end,
  })

  -- On CursorMoved: clear immediately so stale highlights don't linger
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'BufLeave' }, {
    callback = function() clear(vim.api.nvim_get_current_buf()) end,
  })
end

return M
