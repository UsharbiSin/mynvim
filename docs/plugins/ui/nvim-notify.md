[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nvim-notify：通知窗口

仓库：`rcarriga/nvim-notify`。作为 Noice 依赖安装，加载时执行
[nvim-notify.lua](../../../lua/config/nvim-notify.lua)，本项目只把背景色设为黑色。

Snacks 同时启用了自己的 notifier；最终 `vim.notify` 由谁接管取决于加载顺序和 Noice 是否
初始化。遇到重复通知或样式不一致，用 `:verbose lua vim.notify('test')` 不足以定位时，可在
`:lua print(vim.inspect(vim.notify))` 前后观察加载，或临时禁用其中一个 notifier。此插件
可用 `:Notifications` 查看历史（以锁定版本帮助为准）。

上游：[nvim-notify](https://github.com/rcarriga/nvim-notify)。
