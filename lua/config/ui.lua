-- ==========================================
-- 主题与色彩 (tokyonight.nvim)
-- ==========================================
require("tokyonight").setup({
  style = "night",     -- 还有 'storm', 'moon', 'day' 可选，night 最纯粹
  transparent = false, -- 如果你想要磨砂透明终端效果，可以设为 true
  terminal_colors = true,
  styles = {
    -- 修改一些细节，让代码看起来更舒服
    comments = { italic = true }, -- 注释斜体
    keywords = { italic = true }, -- 关键字斜体
    functions = {},
    variables = {},
    -- 重点：让背景稍微暗一点，衬托出 Treesitter 的鲜艳颜色
    sidebars = "dark",
    floats = "dark",
  },
  -- 强制修正一些高亮组
  on_highlights = function(hl, c)
    -- 修正之前提到的断点颜色，确保它们在 Tokyonight 下依然醒目
    hl.DapBreakpoint = { fg = c.red, bold = true }
    hl.DapStoppedLine = { bg = c.green9, bold = true } -- 那个淡绿色的背景
  end,
})

-- 载入主题
vim.cmd [[colorscheme tokyonight-night]]


-- ==========================================
-- 专注阅读模式 (Goyo)
-- ==========================================
-- 绑定开关快捷键
vim.keymap.set('n', '<LEADER>gy', ':Goyo<CR>', { noremap = true, silent = true })


-- ==========================================
-- 可视化缩进线 (vim-indent-guides)
-- ==========================================
-- 缩进线基础设置
vim.g.indent_guides_guide_size = 1
vim.g.indent_guides_start_level = 2
vim.g.indent_guides_enable_on_vim_startup = 1
vim.g.indent_guides_color_change_percent = 1

-- 卸载默认的快捷键映射
vim.cmd([[
  silent! unmap <LEADER>ig
  autocmd WinEnter * silent! unmap <LEADER>ig
]])


-- ==========================================
-- 底部状态栏 (vim-airline)
-- ==========================================
vim.g["airline#extensions#hunks#enable"] = 1


-- ==========================================
-- 显示 Python 虚拟环境 (Conda)
-- ==========================================
-- 定义全局 Lua 函数供 Airline 调用
_G.show_my_env = function()
  local conda_env = vim.env.CONDA_DEFAULT_ENV
  if conda_env and conda_env ~= "" then
    return '🐍️ ' .. conda_env
  else
    return ''
  end
end

-- 设置 Airline 的 X 区 (通常显示文件类型和编码)
-- 使用 %{v:lua.show_my_env()} 来调用上面的 Lua 函数
vim.g.airline_section_x = "%{v:lua.show_my_env()} %y"
