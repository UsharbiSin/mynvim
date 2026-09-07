[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# NERD Commenter：批量注释

仓库：`scrooloose/nerdcommenter`，VeryLazy 加载，使用上游默认映射。常用 Leader 序列包括
`<Space>cc` 注释、`<Space>cu` 取消、`<Space>c<Space>` 切换；可在可视模式对多行使用。

这些默认键可能与本项目 `<Space>ca`（LSP code action）等 Leader 组合相邻，但不相同。
以 `:help NERDCommenter`、`:map <Leader>c` 和 which-key 显示为准。注释格式由 filetype 决定，
识别错误先查 `:set filetype?`。

上游：[nerdcommenter](https://github.com/preservim/nerdcommenter)。
