local M = {}

local treesitter_foldexpr = "v:lua.vim.treesitter.foldexpr()"
local lsp_foldexpr = "v:lua.vim.lsp.foldexpr()"

local function set_foldexpr(bufnr, foldexpr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      vim.wo[win].foldmethod = "expr"
      vim.wo[win].foldexpr = foldexpr
      vim.wo[win].foldlevel = 99
    end
  end
end

function M.use_treesitter(bufnr)
  set_foldexpr(bufnr, treesitter_foldexpr)
end

function M.use_lsp(bufnr)
  set_foldexpr(bufnr, lsp_foldexpr)
end

function M.refresh(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method("textDocument/foldingRange") then
      M.use_lsp(bufnr)
      return
    end
  end
  M.use_treesitter(bufnr)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("SemanticFolding", { clear = true })
  vim.api.nvim_create_autocmd("LspDetach", {
    group = group,
    callback = function(event)
      vim.schedule(function()
        M.refresh(event.buf)
      end)
    end,
  })
end

return M
