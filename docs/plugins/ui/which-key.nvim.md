[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# which-key.nvim：快捷键提示

仓库：`folke/which-key.nvim`，VeryLazy 加载。仓库没有显式调用 setup 或注册分组；锁定版本
的 `plugin/which-key.lua` 会在尚未 setup 时自动用默认配置初始化，所以 Leader 后的已有
描述可以出现在提示窗中。

本项目通过 `vim.keymap.set(..., { desc = ... })` 写了 LSP、DAP、Gitsigns、Codex 等描述，
但一些旧式字符串映射没有描述，提示内容会不完整。该插件当前没有专用 health provider；
用 `:WhichKey` 手动打开，并用 `:messages` 检查错误。要定制分组或延迟，应在插件 spec 增加
正式的 `opts`。

上游：[which-key.nvim](https://github.com/folke/which-key.nvim)。
