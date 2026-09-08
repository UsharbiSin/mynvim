[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nvim-notify：通知窗口

仓库：`rcarriga/nvim-notify`。作为 Noice 依赖安装，加载时执行
[nvim-notify.lua](../../../lua/config/nvim-notify.lua)，本项目把背景色设为黑色，并全局接管
`vim.notify`。

Noice 在启动时全局初始化，Snacks notifier 已关闭，因此普通文件、Markdown、SQL 和调试
会话使用同一套消息及通知样式。此插件可用 `:Notifications` 查看历史（以锁定版本帮助为准）。

上游：[nvim-notify](https://github.com/rcarriga/nvim-notify)。
