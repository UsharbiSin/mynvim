[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# emmet-vim：HTML/CSS 缩写展开

仓库：`mattn/emmet-vim`，在 HTML、CSS、JavaScript 文件加载。默认工作流是在插入模式输入
Emmet 缩写，例如 `ul>li*3`，再按默认 `<C-y>,` 展开。

本项目没有修改 leader、profile 或 filetype 设置。`<C-y>` 是 Emmet 自己的前缀，不是本
项目空格 Leader。若无法展开，用 `:verbose imap <C-y>`、`:EmmetInstall` 和
`:set filetype?` 检查；JavaScript 中是否适用取决于光标语境。它不等于 HTML LSP 补全。

上游：[emmet-vim](https://github.com/mattn/emmet-vim)。
