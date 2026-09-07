[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-javascript：JavaScript 语法

仓库：`pangloss/vim-javascript`，仅 JavaScript 文件加载，增强传统 Vim JavaScript syntax、
缩进和折叠规则。本项目没有 TypeScript LSP，也没有 JavaScript LSP。

JavaScript 同时有 Tree-sitter parser，通常由 `vim.treesitter.start()` 接管高亮；此插件仍可
作为传统语法补充。代码格式化使用 Prettier。F10 调用 Node，但命令写了 POSIX `export`，
Windows 分支尚未适配。用 `:Inspect`、`:set ft?` 判断实际来源。

上游：[vim-javascript](https://github.com/pangloss/vim-javascript)。
