-- Minimal statusline (replaces mini.statusline).
--
-- Layout: MODE  filename [modified]    LSP status/clients    diagnostics    line:col

local M = {}

local mode_map = {
  n = 'NOR', i = 'INS', v = 'VIS', V = 'V-L', ['\22'] = 'V-B',
  c = 'CMD', R = 'REP', t = 'TER', s = 'SEL', S = 'S-L',
}

function M.setup()
  vim.o.statusline = '%!v:lua.Statusline()'
end

function _G.Statusline()
  local mode = mode_map[vim.fn.mode()] or vim.fn.mode()
  local filename = vim.fn.expand '%:t'
  if filename == '' then filename = '[No Name]' end
  local modified = vim.bo.modified and ' [+]' or ''

  -- LSP: show progress if loading, otherwise show attached client names
  local lsp = vim.lsp.status()
  if lsp == '' then
    local clients = vim.lsp.get_clients { bufnr = 0 }
    if #clients > 0 then
      local names = {}
      for _, c in ipairs(clients) do names[#names + 1] = c.name end
      lsp = table.concat(names, ', ')
    end
  end

  -- VCS changes from signify (already cached, no shell call)
  local vcs = ''
  local sy = vim.b.sy
  if sy and sy.stats then
    local a, c, d = sy.stats[1], sy.stats[2], sy.stats[3]
    if a + c + d > 0 then
      vcs = string.format('+%d ~%d -%d', a, c, d)
    end
  end

  -- Search count: [3/15]
  local search = ''
  if vim.v.hlsearch == 1 then
    local ok, sc = pcall(vim.fn.searchcount, { maxcount = 999 })
    if ok and sc.total and sc.total > 0 then
      search = string.format('[%d/%d]', sc.current, sc.total)
    end
  end

  -- Diagnostics: E:0 W:0
  local diag = ''
  if #vim.lsp.get_clients { bufnr = 0 } > 0 then
    local e = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
    local w = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
    if e + w > 0 then
      diag = string.format('E:%d W:%d', e, w)
    end
  end

  return string.format(
    ' %s  %s%s%%=  %s    %s    %s    %s    %%2l:%%2v ',
    mode, filename, modified, lsp or '', vcs, search, diag
  )
end

return M
