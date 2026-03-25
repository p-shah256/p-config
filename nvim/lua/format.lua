-- Format buffer: CLI formatter if configured, otherwise LSP.
-- Replaces conform.nvim plugin.

local M = {}

local formatters_by_ft = {
  lua = { 'stylua', '-' },
  sh = { vim.fn.expand '~/go/bin/shfmt' },
  bash = { vim.fn.expand '~/go/bin/shfmt' },
}

function M.setup()
  vim.keymap.set('n', '<leader>f', function()
    -- Prefer CLI formatter if configured for this filetype
    local cmd = formatters_by_ft[vim.bo.filetype]
    if cmd and vim.fn.executable(cmd[1]) == 1 then
      local buf = vim.api.nvim_get_current_buf()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local input = table.concat(lines, '\n') .. '\n'
      vim.system(cmd, { stdin = input }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            vim.notify('Formatter failed: ' .. (result.stderr or ''), vim.log.levels.ERROR)
            return
          end
          local formatted = vim.split(result.stdout, '\n')
          if formatted[#formatted] == '' then formatted[#formatted] = nil end
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, formatted)
          vim.notify('Formatted with ' .. cmd[1]:match '[^/]+$')
        end)
      end)
      return
    end
    -- Fall back to LSP formatting
    local clients = vim.lsp.get_clients { bufnr = 0 }
    for _, client in ipairs(clients) do
      if client.supports_method 'textDocument/formatting' then
        vim.lsp.buf.format { async = true }
        return
      end
    end
    vim.notify('No formatter for ' .. vim.bo.filetype, vim.log.levels.WARN)
  end, { desc = '[F]ormat buffer' })
end

return M
