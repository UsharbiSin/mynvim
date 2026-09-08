local M = {}

local function find_ctags()
  local executable = vim.fn.exepath("ctags")
  if executable ~= "" then
    return executable
  end
end

function M.setup()
  local ctags = find_ctags()
  if ctags then
    vim.g.tagbar_ctags_bin = ctags
  end
end

function M.toggle()
  M.setup()
  if not vim.g.tagbar_ctags_bin or vim.fn.executable(vim.g.tagbar_ctags_bin) ~= 1 then
    local install = vim.g.is_win == 1 and "winget install UniversalCtags.Ctags" or
      "使用系统包管理器安装 universal-ctags"
    vim.notify("未在 PATH 中找到 ctags，请先执行：" .. install, vim.log.levels.ERROR, { title = "代码结构栏" })
    return
  end
  vim.cmd("TagbarOpenAutoClose")
end

return M
