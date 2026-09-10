[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# indent-blankline.nvim：缩进层级与语法作用域

仓库：`lukas-reineke/indent-blankline.nvim`。配置位于
[indent-guides.lua](../../../lua/config/indent-guides.lua)，普通文件读取后全局启用。

LSP 协议不提供通用的缩进层级或代码块范围。基础缩进线由插件根据 buffer 的
`shiftwidth`、`tabstop` 和实际空白绘制；较亮的当前作用域线由 Tree-sitter 语法树计算，
可以区分当前函数、类或语言定义的作用域。没有对应 Tree-sitter parser 时仍显示基础缩进线，
但不保证显示当前作用域。

JSON 的 `object` 和 `array` 节点会显示当前作用域，JSONC 复用相同的 JSON parser。Markdown
围栏代码只负责嵌入语言高亮和 LSP 诊断，不在 Markdown 主文档中单独绘制围栏内部作用域线。

普通层级使用暗色 `│`，当前语法作用域使用较亮的蓝色 `│`。颜色通过插件的主题重载 hook
重新设置，避免切换主题或创建窗口后消失。终端、帮助、通知、文件树、quickfix 等特殊窗口
不会显示缩进线。

可用 `:IBLToggle` 开关全部缩进线，使用 `:IBLToggleScope` 单独开关当前语法作用域。
执行 `:checkhealth nvim-treesitter` 可排查作用域线缺失。

上游：[indent-blankline.nvim](https://github.com/lukas-reineke/indent-blankline.nvim)。
