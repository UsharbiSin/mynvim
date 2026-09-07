[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# tokyonight.nvim：主配色

仓库：`folke/tokyonight.nvim`。插件 `lazy=false`、优先级 1000，确保其他 UI 前加载。
[ui.lua](../../../lua/config/ui.lua)选用 `tokyonight-night`：不透明背景、终端颜色、斜体注释
和关键字、深色侧栏/浮窗，并调整 DAP 断点与停止行高亮。

切换上游风格可修改 `style` 为 `storm`、`moon` 或 `day`，同时修改最终
`colorscheme`；只改其中一处可能看不到预期效果。检查 `:set termguicolors?` 与
`:colorscheme tokyonight-night`。Windows Terminal 需要 true color 和合适字体。

上游：[TokyoNight](https://github.com/folke/tokyonight.nvim)。
