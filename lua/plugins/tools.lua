local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ==========================================
-- 函数列表 (Tagbar)
-- ==========================================
map('n', 'T', ':TagbarOpenAutoClose<CR>', opts)


-- ==========================================
-- Markdown 表格辅助 (vim-table-mode)
-- ==========================================
map('n', '<LEADER>tm', ':TableModeToggle<CR>', opts)


-- ==========================================
-- Python 语法高亮 (python-syntax)
-- ==========================================
vim.g.python_higlight_all = 1


-- ==========================================
-- 书签与标记可视化 (vim-signature)
-- ==========================================
-- 将 Vim 的字典转换为 Lua 的键值对表
vim.g.SignatureMap = {
  Leader            = "m",
  PlaceNextMark     = "m,",
  ToggleMarkAtLine  = "m.",
  PurgeMarksAtLine  = "dm-",
  DeleteMark        = "dm",
  PurgeMarks        = "dm/",
  PurgeMarkers      = "dm?",
  GotoNextLineAlpha = "m<LEADER>",
  GotoPrevLineAlpha = "",
  GotoNextSpotAlpha = "m<LEADER>",
  GotoPrevSpotAlpha = "",
  GotoNextLineByPos = "",
  GotoPrevLineByPos = "",
  GotoNextSpotByPos = "mn",
  GotoPrevSpotByPos = "mp",
  GotoNextMarker    = "",
  GotoPrevMarker    = "",
  GotoNextMarkerAny = "",
  GotoPrevMarkerAny = "",
  ListLocalMarks    = "m/",
  ListLocalMarkers  = "m?"
}
