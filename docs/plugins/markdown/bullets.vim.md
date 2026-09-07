[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# bullets.vim：列表续写与层级

仓库：`bullets-vim/bullets.vim`，只在 Markdown、Vimwiki、text 加载。本项目仅设置启用文件
类型，其余使用默认行为：在列表项末尾按 Enter 续写 bullet/编号，空项目回车结束列表，
Tab/Shift-Tab 可调整层级（以 `:help bullets` 为准）。

Markdown ftplugin 会在 Table Mode 开启时临时接管插入模式 Enter，并保存/恢复原映射，目的是
表格内生成分隔行和 `<++>` 数据行。若退出表格模式后 Enter 异常，用
`:verbose imap <CR>` 检查是否正确恢复。上游：[bullets.vim](https://github.com/bullets-vim/bullets.vim)。
