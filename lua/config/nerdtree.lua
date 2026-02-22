local map = vim.keymap.set

-- ----------------------
-- NERDTree
-- ----------------------
map('n', 'tt', ':NERDTreeToggle<CR>')
vim.g.NERDTreeMapOpenExpl = ""         -- 打开文件系统浏览器
vim.g.NERDTreeMapUpdir = "u"           -- 将目录向上提一级
vim.g.NERDTreeMapUpdirKeepOpen = "U"   -- 将文件树的根目录向上提一级（变成父目录）
vim.g.NERDTreeMapOpenSplit = ""        -- 在垂直分屏中打开文件
vim.g.NERDTreeOpenVSplit = ""          -- 在水平分屏中打开文件
vim.g.NERDTreeMapActivateNode = "<CR>" -- 激活节点
vim.g.NERDTreeMapOpenInTab = "t"       -- 如果光标在一个文件上，按t则会在新标签页中打开这个文件
vim.g.NERDTreeMapPreview = ""          -- 预览文件
vim.g.NERDTreeMapCloseDir = "x"        -- 折叠光标所在的整个父目录
vim.g.NERDTreeMapChangeRoot = "C"      -- 把光标当前选中的文件夹直接设置为整棵文件树的顶级根目录


-- ----------------------
-- NERDTree-git
-- ----------------------
vim.g.NERDTreeIndicatorMapCustom = {
  Modified  = "✹",
  Staged    = "✚",
  Untracked = "✭",
  Renamed   = "➜",
  Unmerged  = "═",
  Deleted   = "✖",
  Dirty     = "✗",
  Clean     = "✔︎",
  Unknown   = "?"
}
