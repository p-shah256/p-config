-- Minimal auto-pairs: insert closing pair, skip if already there, delete both.
-- Replaces nvim-autopairs plugin.

local M = {}

local pairs_map = { ['('] = ')', ['['] = ']', ['{'] = '}', ['"'] = '"', ["'"] = "'" }

local function char_after()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local line = vim.api.nvim_get_current_line()
  return line:sub(col + 1, col + 1)
end

local function char_before()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local line = vim.api.nvim_get_current_line()
  return line:sub(col, col)
end

function M.setup()
  for open, close in pairs(pairs_map) do
    vim.keymap.set('i', open, function()
      local after = char_after()
      -- For quotes: skip if already on that quote
      if open == close and after == close then
        return '<Right>'
      end
      -- For quotes: don't pair if char before is alphanumeric (e.g. it's, don't)
      if open == close and char_before():match '[%w]' then
        return open
      end
      return open .. close .. '<Left>'
    end, { expr = true, noremap = true })

    if open ~= close then
      -- Skip closing char if it's already there
      vim.keymap.set('i', close, function()
        if char_after() == close then
          return '<Right>'
        end
        return close
      end, { expr = true, noremap = true })
    end
  end

  -- Backspace: delete both if cursor is between a pair
  vim.keymap.set('i', '<BS>', function()
    local before = char_before()
    local after = char_after()
    if pairs_map[before] and pairs_map[before] == after then
      return '<BS><Del>'
    end
    return '<BS>'
  end, { expr = true, noremap = true })

  -- Enter: expand pair with indented blank line
  vim.keymap.set('i', '<CR>', function()
    local before = char_before()
    local after = char_after()
    if pairs_map[before] and pairs_map[before] == after and before ~= '"' and before ~= "'" then
      return '<CR><CR><Up><C-f>'
    end
    return '<CR>'
  end, { expr = true, noremap = true })
end

return M
