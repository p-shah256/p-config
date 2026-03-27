-- Minimal statusline (replaces mini.statusline).
-- Adapts to window width: narrows gracefully in splits.

local M = {}

local mode_map = {
  n = 'NOR', i = 'INS', v = 'VIS', V = 'V-L', ['\22'] = 'V-B',
  c = 'CMD', R = 'REP', t = 'TER', s = 'SEL', S = 'S-L',
}

function M.setup()
  vim.o.statusline = '%!v:lua.Statusline(g:statusline_winid)'
end

function _G.Statusline(winid)
  winid = winid or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local w = vim.api.nvim_win_get_width(winid)
  local mode = mode_map[vim.fn.mode()] or vim.fn.mode()
  local fullpath = vim.api.nvim_buf_get_name(bufnr)
  local filename
  if fullpath == '' then
    filename = '[No Name]'
  elseif w < 60 then
    filename = vim.fn.fnamemodify(fullpath, ':t')
  else
    filename = vim.fn.fnamemodify(fullpath, ':.')
  end
  local modified = vim.bo[bufnr].modified and ' [+]' or ''

  -- Narrow: just mode + filename + position
  if w < 60 then
    return string.format(' %s  %s%s%%= %%2l:%%2v ', mode, filename, modified)
  end

  -- Diagnostics
  local diag = ''
  local e = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
  local warn = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN })
  if e + warn > 0 then
    diag = string.format('E:%d W:%d', e, warn)
  end

  -- Search count
  local search = ''
  if vim.v.hlsearch == 1 then
    local ok, sc = pcall(vim.fn.searchcount, { maxcount = 999 })
    if ok and sc.total and sc.total > 0 then
      search = string.format('[%d/%d]', sc.current, sc.total)
    end
  end

  -- VCS changes from signify
  local vcs = ''
  if w >= 80 then
    local sy = vim.b[bufnr].sy
    if sy and sy.stats then
      local a, c, d = sy.stats[1], sy.stats[2], sy.stats[3]
      if a + c + d > 0 then
        vcs = string.format('+%d ~%d -%d', a, c, d)
      end
    end
  end

  return string.format(
    ' %s  %s%s%%=  %s    %s    %s    %%2l:%%2v ',
    mode, filename, modified, vcs, search, diag
  )
end

return M
