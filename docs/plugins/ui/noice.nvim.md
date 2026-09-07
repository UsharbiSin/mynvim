[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# noice.nvim：消息和命令行界面

仓库：`folke/noice.nvim`，依赖 [nui.nvim](nui.nvim.md) 与
[nvim-notify](nvim-notify.md)，在 VeryLazy 事件下载/加载。

插件声明没有直接 `opts` 或 `config`。当前真正的 `noice.setup()` 位于
[debugging.lua](../../../lua/config/debugging.lua)：首次打开 Python、C、C++ 或 CUDA 文件并
加载 DAP 时才调用。因此在只编辑普通文本的会话里，Noice 可能已加载代码但尚未初始化；
这与“始终美化命令行”的注释不完全一致。

用 `:lua print(require('noice.config').is_running())`、`:Noice history` 与 `:checkhealth noice`
检查。若希望所有会话启用，应把 setup 放到插件自身 config。上游：
[noice.nvim](https://github.com/folke/noice.nvim)。
