-- Lightweight linting: runs CLI linters and feeds results into vim.diagnostic.
-- Replaces nvim-lint plugin.

local M = {}
local ns = vim.api.nvim_create_namespace 'custom_lint'

local linters_by_ft = {
  sh = { 'shellcheck', '-f', 'json', '-' },
  bash = { 'shellcheck', '-f', 'json', '-' },
}

local severity_map = {
  error = vim.diagnostic.severity.ERROR,
  warning = vim.diagnostic.severity.WARN,
  info = vim.diagnostic.severity.INFO,
  style = vim.diagnostic.severity.HINT,
}

local function run_lint(buf)
  local cmd = linters_by_ft[vim.bo[buf].filetype]
  if not cmd or vim.fn.executable(cmd[1]) ~= 1 then
    -- print("No linters for this filetype found")
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local input = table.concat(lines, '\n') .. '\n'
  vim.system(cmd, { stdin = input }, function(result)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      local diagnostics = {}
      local ok, parsed = pcall(vim.json.decode, result.stdout or '[]')
      if ok and type(parsed) == 'table' then
        for _, item in ipairs(parsed) do
          diagnostics[#diagnostics + 1] = {
            lnum = (item.line or 1) - 1,
            col = (item.column or 1) - 1,
            end_lnum = (item.endLine or item.line or 1) - 1,
            end_col = (item.endColumn or item.column or 1) - 1,
            message = item.message or '',
            severity = severity_map[item.level] or vim.diagnostic.severity.WARN,
            source = 'shellcheck',
            code = item.code,
          }
        end
      end
      vim.diagnostic.set(ns, buf, diagnostics)
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
    callback = function(event)
      if vim.bo[event.buf].modifiable then
        run_lint(event.buf)
      end
    end,
  })
end

return M
