[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# diagram.nvim：文档代码块图表渲染

仓库：`3rd/diagram.nvim`，仅 windows 分支安装。Markdown、Vimwiki 或 Neorg 文件加载，
Windows 配置位于 `lua/config/diagram.lua`，图像显示依赖 [image.nvim](../dependencies/image.nvim.md)。

本项目启用 Mermaid、PlantUML、D2 和 Gnuplot 渲染器。Windows 实机已确认 Mermaid CLI
`mmdc` 可用，Snacks health 能识别 Mermaid；PlantUML、D2 与 Gnuplot 需按用途另行安装。
Markdown 集成也接受 `vimwiki` filetype，因此 Vimwiki 接管 `.md` 文件后仍可解析围栏代码块。

排错时先运行 `:set filetype?`、`:checkhealth snacks`，再分别检查 `mmdc --version`、
`plantuml -version`、`d2 version` 或 `gnuplot --version`。终端本身还需支持 image.nvim 使用的
图像协议。

上游：[diagram.nvim](https://github.com/3rd/diagram.nvim)。
