-- ==========================================
-- 主题与色彩 (tokyonight.nvim)
-- ==========================================
require("tokyonight").setup({
  style = "night",     -- 还有 'storm', 'moon', 'day' 可选，night 最纯粹
  transparent = false, -- 如果你想要磨砂透明终端效果，可以设为 true
  terminal_colors = true,
  styles = {
    comments = { italic = true }, -- 注释斜体
    keywords = { italic = true }, -- 关键字斜体
    functions = {},
    variables = {},
    sidebars = "dark",
    floats = "dark",
  },
  on_colors = function(colors) end,
  -- 强制修正一些高亮组
  on_highlights = function(hl, c)
    -- 断点颜色
    hl.DapBreakpoint = { fg = c.red, bold = true }
    hl.DapStoppedLine = { bg = c.green, bold = true }
  end,
})

-- 载入主题
vim.cmd [[colorscheme tokyonight-night]]
