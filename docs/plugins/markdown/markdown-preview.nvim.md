[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# markdown-preview.nvim：浏览器实时预览

仓库：`iamcco/markdown-preview.nvim`。Markdown/Vimwiki 或预览命令触发加载；安装时在 `app`
目录运行 `npm install`，因此首次安装需要 Node.js/npm。配置见
[markdown.lua](../../../lua/config/markdown.lua)。

F8 启动 `MarkdownPreview`，F9 停止；也可用 `:MarkdownPreviewToggle`。本项目实时刷新、切换
buffer 自动关闭、深色主题、KaTeX、Mermaid/PlantUML 等预览选项，默认只监听本机。

main 的浏览器、CSS 和图片路径含作者绝对路径；windows 的 CSS 已用 stdpath，但 Chrome
路径仍需核对。F10 调用的是另一个不存在的 `InstantMarkdownPreview`，请使用 F8。构建失败
看 `:Lazy log`，预览失败可临时清空 `vim.g.mkdp_browser` 让系统选择默认浏览器。

上游：[markdown-preview.nvim](https://github.com/iamcco/markdown-preview.nvim)。
