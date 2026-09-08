-- 全局接管消息、命令行和补全菜单，不依赖特定文件类型或 DAP。
require("noice").setup({
  cmdline = { enabled = true },
  messages = { enabled = true },
  popupmenu = { enabled = true },
  notify = { enabled = true },
})
