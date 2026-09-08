-- 关闭 Diff 窗口的自动打开，保持界面清爽
vim.g.undotree_DiffAutoOpen = 0

-- Windows 的 Git 自带 diff.exe，但 Git\usr\bin 通常不在 PATH 中。
if vim.g.is_win == 1 and vim.fn.executable("diff") ~= 1 then
  local git = vim.fn.exepath("git")
  if git ~= "" then
    local git_root = vim.fs.dirname(vim.fs.dirname(git))
    local git_tools = vim.fs.joinpath(git_root, "usr", "bin")
    local diff = vim.fs.joinpath(git_tools, "diff.exe")
    if vim.fn.executable(diff) == 1 then
      vim.env.PATH = git_tools .. ";" .. (vim.env.PATH or "")
    end
  end
end

-- 绑定快捷键 L 打开/关闭历史撤销树
vim.keymap.set('n', 'L', ':UndotreeToggle<CR>', {
  noremap = true,
  silent = true,
  desc = '打开或关闭撤销历史树',
})
