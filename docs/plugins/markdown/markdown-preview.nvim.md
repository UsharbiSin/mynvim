[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# markdown-preview.nvim：浏览器实时预览

仓库：`iamcco/markdown-preview.nvim`。Markdown/Vimwiki 或预览命令触发加载；安装时在 `app`
目录调用上游提供的 `mkdp#util#install()`，因此首次安装需要 Node.js/npm。该安装入口会按
平台构建预览程序，避免直接执行 `npm install` 时重写上游 `app/yarn.lock` 或生成
`package-lock.json`，从而导致后续 `:Lazy sync` 被本地修改阻止。配置见
[markdown.lua](../../../lua/config/markdown.lua)。

F8 启动 `MarkdownPreview`，F9 停止；也可用 `:MarkdownPreviewToggle`。本项目实时刷新、切换
buffer 自动关闭、深色主题、KaTeX、Mermaid/PlantUML 等预览选项，默认只监听本机。

main 的浏览器、CSS 和图片路径含作者绝对路径；windows 的 CSS 使用 stdpath，浏览器配置
留空并使用系统默认浏览器。F10 与 F8 都调用已安装的 `MarkdownPreview`。构建失败看
`:Lazy log`；实机已确认预览服务能生成本地 URL。

上游：[markdown-preview.nvim](https://github.com/iamcco/markdown-preview.nvim)。
