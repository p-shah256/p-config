-- Close buffer without closing window (replaces mini.bufremove).
--
-- :Bd switches to the alternate/previous buffer first, then wipes the
-- original. This keeps your window layout intact unlike :bdelete.

local M = {}

function M.setup()
  vim.api.nvim_create_user_command('Bd', function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].modified then
      vim.notify('Buffer has unsaved changes', vim.log.levels.ERROR)
      return
    end
    local alt = vim.fn.bufnr '#'
    if alt > 0 and alt ~= buf and vim.fn.buflisted(alt) == 1 then
      vim.cmd 'buffer #'
    else
      vim.cmd 'bprevious'
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = false })
    end
  end, {})

  -- Make :bd use :Bd automatically
  vim.cmd [[cnoreabbrev <expr> bd getcmdtype() == ':' && getcmdline() ==# 'bd' ? 'Bd' : 'bd']]
end

return M
