[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-table-mode：文本表格编辑

仓库：`dhruvasagar/vim-table-mode`，执行 `:TableModeToggle` 或 `<Space>tm` 时加载；配置见
[vim-table-mode.lua](../../../lua/config/vim-table-mode.lua)，表格回车增强在
[ftplugin/markdown.lua](../../../ftplugin/markdown.lua)。

本项目使用 `|` 作为角、分隔与对齐字符，`-` 填充。Markdown 中启用后，输入 `|` 不会临时
退出插入模式，因此中文输入法保持不变。如果当前行形如 `| ... |`，插入模式 Enter 会直接
生成首个分隔行及下一数据行，空单元格用 `<++>`；之后按两次 Space 逐个填写。表中任意一行
增加新列时，当前空单元格会填入 `<++>`，其余表头、分隔行和数据行也会自动补齐对应列；在
空白标题行连续输入 `||||` 会得到三个 `<++>` 单元格。关闭 Table Mode 时恢复 bullets.vim
的 Enter 映射。

若表格被意外改写，立即 `u`；用 `:TableModeRealign` 重排，`:messages` 与
`:verbose imap <CR>` 排查。普通文本对齐可用 Tabular。

上游：[vim-table-mode](https://github.com/dhruvasagar/vim-table-mode)。
