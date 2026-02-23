-- snacks.nvim 动态模式渲染配置 (Normal渲染，其他模式纯文本)
require("snacks").setup({
  toggle = { enable = true },
  notifier = { enable = true },
  image = {
    enabled = true,
    doc = {
      -- 开启行内渲染
      inline = true,
      -- 悬浮窗
      float = true,
      max_width = 80,
    },
  }
})

-- 悬浮窗响应速度
vim.opt.updatetime = 200
local function show_hover()
  if Snacks and Snacks.image then
    Snacks.image.hover()
  end
end
-- 创建自动命令组
local group = vim.api.nvim_create_augroup("SnacksImageHover", { clear = true })
-- 光标停留时触发 (n/i 模式通用)
vim.api.nvim_create_autocmd("CursorHold", {
  group = group,
  callback = show_hover,
})
-- 在插入模式下，光标移动时也尝试刷新 (保证 i 模式下跳跃占位符后能立刻出图)
vim.api.nvim_create_autocmd("CursorMovedI", {
  group = group,
  callback = show_hover,
})

vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
  -- 解决 Vimwiki 文件类型被 Snacks 无视的问题
  -- 当进入 vimwiki 或 markdown 文件时，强制触发 Snacks 的文档图片渲染解析
  pattern = { "vimwiki", "markdown" },
  callback = function(args)
    -- 安全地强制把当前 buffer 喂给 snacks 渲染引擎
    if Snacks and Snacks.image and Snacks.image.doc then
      pcall(Snacks.image.doc.attach, args.buf)
    end
  end
})
