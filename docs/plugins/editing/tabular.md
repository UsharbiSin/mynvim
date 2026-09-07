[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# tabular：按分隔符对齐

仓库：`godlygeek/tabular`。执行 `:Tabularize` 时加载。它按正则分隔符对齐多行文本，例如
可视选择多行后执行 `:Tabularize /=` 对齐等号，或 `:Tabularize /|` 对齐管道符。

正则写错可能大幅改动空格，先在小范围可视选择中测试，出错用 `u`。Markdown 表格优先用
[vim-table-mode](../markdown/vim-table-mode.md)，它了解表格边界；Tabular 更适合通用文本。

上游：[Tabular](https://github.com/godlygeek/tabular)。
