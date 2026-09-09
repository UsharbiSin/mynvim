[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# img-clip.nvim：剪贴板图片保存

仓库：`HakonHarnes/img-clip.nvim`。Markdown/Vimwiki、VeryLazy 或 `<Space>pi` 触发，配置见
[img-clip.lua](../../../lua/config/img-clip.lua)。

按 `<Space>pi` 后不询问文件名，将图片放进当前文档旁的 `.markdown_images/`，文件名包含
时间，并插入带 `image<++>` 替代文本和文件路径的 Markdown 图片链接；完成后保持 Normal
模式。之后可按两次 Space 跳到 `<++>`。Windows 使用剪贴板接口原生支持的 PNG；Linux 调用
`magick convert - -quality 75 avif:-` 转成 AVIF。

Windows 粘贴 PNG 不依赖 ImageMagick；Linux 需安装系统剪贴板工具和支持 AVIF 的
ImageMagick。该插件没有专用 health provider；按 `<Space>pi` 后检查目标目录和
`:messages`。保存成功但不显示属于 Snacks/终端问题，可运行 `:checkhealth snacks`。路径
权限和远程 SSH 剪贴板也会影响结果。

上游：[img-clip.nvim](https://github.com/HakonHarnes/img-clip.nvim)。
