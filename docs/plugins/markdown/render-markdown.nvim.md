[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# render-markdown.nvim：编辑器内 Markdown 渲染

仓库：`MeanderingProgrammer/render-markdown.nvim`。Markdown、Vimwiki、`Avante` filetype 加载，
依赖 nvim-treesitter 和 mini.nvim。配置见
[render-markdown.lua](../../../lua/config/render-markdown.lua)。

本项目渲染标题边框、代码块、圆角表格、Wiki/图片/站点链接图标、GitHub/Obsidian 风格
callout，并扩展 `[?]`、`[>]`、`[-]`、`[!]`、`[~]` checkbox。sign 关闭；标题在插入模式
仍渲染，Normal 模式的 anti-conceal 被关闭，因此源码标记可能隐藏。

用 `:RenderMarkdown toggle` 切换，`:checkhealth render-markdown` 排错。它要求 Markdown 与
markdown_inline parser；图标要求 Nerd Font。配置开启 blink/LSP completion，但本项目没有
blink.cmp，不能据此假定该补全已存在。

上游：[render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)。
