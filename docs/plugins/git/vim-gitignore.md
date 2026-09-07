[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-gitignore：gitignore 语法与片段

仓库：`gisphm/vim-gitignore`，仅在 `gitignore` filetype 加载。它提供 `.gitignore` 语法和
针对常见语言/工具的 snippet 文件。

本项目没有安装 snipMate、UltiSnips 或 neosnippet，也没有把这些 snippet 接到 nvim-cmp，
所以不能把它当成已配置的一键 `.gitignore` 生成器；当前确定可用的是语法支持。用
`:set filetype?` 确认 `.gitignore` 被识别。要生成模板可手工编辑或另配 snippet 引擎。

上游：[vim-gitignore](https://github.com/gisphm/vim-gitignore)。
