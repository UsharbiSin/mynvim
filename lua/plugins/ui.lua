-- ==========================================
-- 主题与色彩 (vim-snazzy)
-- ==========================================
-- 开启透明背景并应用主题
vim.g.SnazzyTransparent = 1
vim.cmd("colorscheme snazzy")


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
-- 开启 coc.nvim 支持及自定义报错/警告图标 [cite: 32]
vim.g["airline#extensions#coc#enabled"] = 1
vim.g["airline#extensions#coc#error_symbol"] = '❌: '
vim.g["airline#extensions#coc#warning_symbol"] = '⚡: '
vim.g["airline#extensions#coc#show_coc_status"] = 1


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


-- ==========================================
-- 提取并格式化当前函数名 (配合 coc.nvim)
-- ==========================================
_G.coc_current_function = function()
  -- 获取 b:coc_symbol_line 变量
  local status, symbol = pcall(function() return vim.b.coc_symbol_line end)

  if status and symbol and symbol ~= "" then
    -- 使用 Lua 的 gsub 替代 Vimscript 的 substitute
    -- 剔除颜色控制、鼠标点击代码、点击结束符和颜色重置符
    symbol = symbol:gsub("%%#.-#", "")
    symbol = symbol:gsub("%%%d+@.-@", "")
    symbol = symbol:gsub("%%X", "")
    symbol = symbol:gsub("%%[*]", "")
  else
    -- 如果没获取到，降级回退到原生单函数名 [cite: 34]
    status, symbol = pcall(function() return vim.b.coc_current_function end)
  end

  -- 拼接并返回显示字符串
  if status and symbol and symbol ~= "" then
    return '  ' .. symbol
  else
    return ''
  end
end

-- 使用 airline#section#create 构建 C 区 (通常显示文件名)
vim.g.airline_section_c = vim.fn['airline#section#create']({
  '%<',
  'file',
  ' ',
  'readonly',
  '%{v:lua.coc_current_function()}'
})

-- 确保开启 coc.nvim 支持
-- vim.g['airline#extensions#coc#enabled'] = 1
