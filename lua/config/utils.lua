-- 创建一个空的 Lua 表（Table），通常命名为 M (Module 的缩写)
-- 我们把所有需要导出的函数都挂载到这个表上，最后将其返回。
-- 这样其他文件就可以通过 require('你的文件名') 来调用这些函数了。
local M = {}

-- ==========================================
-- 检查当前缓冲区 (Buffer) 是否有 LSP 服务器附加
-- ==========================================
M.is_lsp_attached = function()
  -- 获取当前活动缓冲区的所有 LSP 客户端实例
  local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
  -- next() 是 Lua 内置函数，用于检查表是否为空。如果不为空 (nil)，说明有 LSP 连接
  return next(clients) ~= nil
end

-- ==========================================
-- 判断当前操作系统是否为 macOS
-- ==========================================
M.is_mac = function()
  -- 获取底层系统的名称信息
  ---@diagnostic disable-next-line: undefined-field
  local uname = vim.uv.os_uname()
  -- Darwin 是 macOS 的系统内核名称
  return uname.sysname == "Darwin"
end

-- ==========================================
-- 在指定文件类型的窗口上执行自定义函数
-- ==========================================
-- 参数 window_name: 目标窗口的文件类型 (filetype)，比如 "NvimTree" 或 "OverseerList"
-- 参数 myfunc: 找到对应窗口后需要执行的回调函数
M.func_on_window = function(window_name, myfunc)
  -- 遍历当前所有打开的窗口 (Window)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    -- 获取该窗口对应的缓冲区 (Buffer)
    local buf = vim.api.nvim_win_get_buf(win)
    -- 获取该缓冲区的文件类型 (filetype)
    local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })

    -- 如果文件类型匹配，就执行传入的函数，并跳出循环
    if ft == window_name then
      myfunc()
      break
    end
  end
end

-- ==========================================
-- 重置 Overseer 任务列表窗口的宽度
-- ==========================================
-- 这通常用于防止某些侧边栏插件（如 DAP UI）挤压任务列表的显示空间
M.reset_overseerlist_width = function()
  -- 同样遍历所有打开的窗口
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })

    -- 当找到文件类型为 "OverseerList" 的窗口时
    if ft == "OverseerList" then
      -- 计算目标宽度：当前 Neovim 整体列宽 (vim.o.columns) 的 20%
      -- math.floor 用于向下取整，确保宽度是整数
      local target_width = math.floor(vim.o.columns * 0.2)

      -- 将计算好的宽度设置给该窗口
      vim.api.nvim_win_set_width(win, target_width)
      break
    end
  end
end

-- 最后将这个包含了所有函数的表返回
return M
