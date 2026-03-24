-- Auto-detect indent style (tabs vs spaces, width) from file contents.
-- Replaces guess-indent.nvim plugin.
--
-- On BufReadPost, scans first 200 lines. If most indented lines use tabs,
-- sets noexpandtab. Otherwise finds the most common space indent width (2/4/8).

local M = {}

function M.setup()
  vim.api.nvim_create_autocmd('BufReadPost', {
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(0, 0, 200, false)
      local tabs, spaces = 0, 0
      local widths = {} -- count of lines per indent width

      for _, line in ipairs(lines) do
        if line:match '^%s+%S' then -- indented, non-blank
          if line:match '^\t' then
            tabs = tabs + 1
          else
            spaces = spaces + 1
            local indent = #(line:match '^( +)')
            for _, w in ipairs { 2, 4, 8 } do
              if indent % w == 0 then
                widths[w] = (widths[w] or 0) + 1
              end
            end
          end
        end
      end

      if tabs + spaces < 3 then return end -- not enough data

      if tabs > spaces then
        vim.bo.expandtab = false
      else
        vim.bo.expandtab = true
        -- pick the smallest width that explains the most lines
        local best_w = 4
        local best_count = 0
        for _, w in ipairs { 2, 4, 8 } do
          if (widths[w] or 0) > best_count then
            best_count = widths[w] or 0
            best_w = w
          end
        end
        vim.bo.shiftwidth = best_w
        vim.bo.tabstop = best_w
        vim.bo.softtabstop = best_w
      end
    end,
  })
end

return M
