[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# wildfire.vim：逐层选择文本对象

仓库：`gcmt/wildfire.vim`，VeryLazy 加载，无自定义配置。在普通模式按 Enter 进入可视选择，
继续按 Enter 按语法周边逐层扩大；Backspace 通常缩小，具体由文件类型和上游映射决定。

Markdown ftplugin 在 Table Mode 开启时会临时接管插入模式 Enter，但不影响普通模式 Wildfire。
若 Enter 行为不符，用 `:verbose nmap <CR>` 和 `:verbose imap <CR>` 分别检查模式。

上游：[wildfire.vim](https://github.com/gcmt/wildfire.vim)。
