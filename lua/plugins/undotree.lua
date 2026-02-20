-- 关闭 Diff 窗口的自动打开，保持界面清爽
vim.g.undotree_DiffAutoOpen = 0

-- 绑定快捷键 L 打开/关闭历史撤销树
vim.keymap.set('n', 'L', ':UndotreeToggle<CR>', { noremap = true, silent = true })
