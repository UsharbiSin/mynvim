[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-css3-syntax：CSS3 语法补充

仓库：`hail2u/vim-css3-syntax`，仅 CSS 文件加载，补充属性、选择器、媒体查询等传统 syntax。
本项目没有配置选项。

CSS 同时在 Tree-sitter parser 列表中，因此最终高亮可能主要来自 Tree-sitter；传统 syntax
仍可在 parser 缺失或停止时生效。它不提供 CSS LSP、补全或格式化，保存格式化由 Prettier
与 Conform 完成。用 `:Inspect` 查看光标处实际高亮来源。

上游：[vim-css3-syntax](https://github.com/hail2u/vim-css3-syntax)。
