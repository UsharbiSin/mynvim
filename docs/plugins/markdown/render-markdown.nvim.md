[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# render-markdown.nvim：编辑器内 Markdown 渲染

仓库：`MeanderingProgrammer/render-markdown.nvim`。Markdown、Vimwiki、`Avante` filetype 加载，
依赖 nvim-treesitter 和 mini.nvim。配置见
[render-markdown.lua](../../../lua/config/render-markdown.lua)。

本项目渲染标题边框、代码块、圆角表格、Wiki/图片/站点链接图标、GitHub/Obsidian 风格
callout，并扩展 `[?]`、`[>]`、`[-]`、`[!]`、`[~]` checkbox。sign 关闭；标题在插入模式
仍渲染。Normal 模式的当前行会隐藏 `**`、反引号等源码标记，进入 Insert 模式后显示这些
标记以便编辑。

内联 HTML 额外支持 `<a>` 和 `<span>` 的 `style="color: ..."`。例如
`<span style="color: red;">警告</span>` 在 Normal 模式隐藏标签并把“警告”显示为红色，
进入 Insert 模式后显示完整标签并实时更新颜色。颜色可使用名称、`#RGB`、`#RRGGBB` 或
`rgb(r, g, b)`；其他 CSS 属性、跨行标签和嵌套标签仍交给浏览器预览。空标签没有可渲染的正文。

用 `:RenderMarkdown toggle` 切换；该插件没有专用 health provider，可用
`:checkhealth nvim-treesitter` 和 `:messages` 排错。它要求 Markdown 与 markdown_inline
parser；图标要求 Nerd Font。配置开启 blink/LSP completion，但本项目没有
blink.cmp，不能据此假定该补全已存在。

上游：[render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)。
