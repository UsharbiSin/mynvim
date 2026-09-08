[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# noice.nvim：消息和命令行界面

仓库：`folke/noice.nvim`，依赖 [nui.nvim](nui.nvim.md) 与
[nvim-notify](nvim-notify.md)。插件在 Neovim 启动时全局加载并初始化。

全局配置位于 [noice.lua](../../../lua/config/noice.lua)，统一接管消息、命令行和补全菜单，
不依赖文件类型，也不需要先启动 Python 或 DAP。nvim-notify 负责通知窗口；Snacks 的
notifier 已关闭，避免多个插件按加载顺序反复覆盖 `vim.notify`。

用 `:lua print(require('noice.config').is_running())`、`:Noice history` 与 `:messages` 检查；
正常启动后 `is_running()` 应返回 `true`。当前插件没有专用 health provider。上游：
[noice.nvim](https://github.com/folke/noice.nvim)。
