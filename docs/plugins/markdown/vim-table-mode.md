[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-table-mode：文本表格编辑

仓库：`dhruvasagar/vim-table-mode`，执行 `:TableModeToggle` 或 `<Space>tm` 时加载；配置见
[vim-table-mode.lua](../../../lua/config/vim-table-mode.lua)，表格回车增强在
[ftplugin/markdown.lua](../../../ftplugin/markdown.lua)。

本项目使用 `|` 作为角、分隔与对齐字符，`-` 填充。Markdown 中启用后，如果当前行形如
`| ... |`，插入模式 Enter 会自动生成首个分隔行及下一数据行，空单元格用 `<++>`；之后按
两次 Space 逐个填写。关闭 Table Mode 时尝试恢复 bullets.vim 的 Enter 映射。

若表格被意外改写，立即 `u`；用 `:TableModeRealign` 重排，`:messages` 与
`:verbose imap <CR>` 排查。普通文本对齐可用 Tabular。

上游：[vim-table-mode](https://github.com/dhruvasagar/vim-table-mode)。
