-- ==========================================
-- 专注阅读模式 (Goyo)
-- ==========================================
-- 绑定开关快捷键
vim.keymap.set('n', '<LEADER>gy', ':Goyo<CR>', { noremap = true, silent = true })


-- ==========================================
-- 底部状态栏 (vim-airline)
-- ==========================================
vim.g["airline#extensions#hunks#enabled"] = 1


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
