[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-cursorword：当前单词高亮

仓库：`itchyny/vim-cursorword`，VeryLazy 加载，无自定义配置。光标停留或移动时，它高亮
其他相同单词，便于阅读变量使用位置。

这不是语义引用查询：字符串或注释中的同词也可能高亮。LSP 还会在 CursorHold 调用
documentHighlight，两者可能叠加；颜色过重时可禁用一方或调整 `CursorWord` 高亮组。
用 `:highlight CursorWord` 检查实际颜色。

上游：[vim-cursorword](https://github.com/itchyny/vim-cursorword)。
