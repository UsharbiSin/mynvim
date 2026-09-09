[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# snacks.nvim：图片、公式、通知与 Codex 终端

仓库：`folke/snacks.nvim`，优先级 1000。插件启动即加载，配置见
[snacks.lua](../../../lua/config/snacks.lua)。

两个系统均启用 image、toggle、notifier：Markdown/Vimwiki 中行内或浮窗显示图片，光标停留
约 200ms 调用 hover，并显式 attach 文档图片解析。图片/公式需要 Tree-sitter parser；除 PNG
外的转换通常需要 ImageMagick，数学公式还可能需要 Typst，实际终端必须支持图像协议。
运行 `:checkhealth snacks` 查看终端、转换器与环境探测。

两个系统都启用 terminal 并初始化 [Codex 模块](../../codex.md)：`<Space>ac` 开关项目终端，
`<Space>ar` 恢复会话。Snacks notifier 与 nvim-notify/Noice 可能竞争通知接管者，出现重复
通知时检查加载顺序。

上游：[snacks.nvim](https://github.com/folke/snacks.nvim)。
