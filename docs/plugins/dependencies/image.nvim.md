[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# image.nvim：终端图像后端

仓库：`3rd/image.nvim`，作为 diagram.nvim 的依赖安装并使用默认配置。它负责把图表渲染结果
显示在 Neovim 中，本项目没有为它单独设置快捷键。

显示能力取决于终端图像协议和转换工具。Windows 实机的 `:checkhealth snacks` 已识别 WezTerm
与 ImageMagick；无界面检查的 `TERM=dumb` 不具备图像协议，因此该环境里的协议警告不能代表
交互式 WezTerm 失败。先在正常终端会话测试，再检查 `magick`、渲染器和终端设置。

main 已同步相同依赖声明，但 Linux 尚未实机验证；需要在实际终端中确认图像协议和
ImageMagick 后端。

上游：[image.nvim](https://github.com/3rd/image.nvim)。
