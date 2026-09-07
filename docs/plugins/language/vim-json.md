[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-json：JSON 语法

仓库：`elzr/vim-json`，仅 `json` filetype 加载，为传统 Vim syntax 提供 JSON 高亮与折叠选项。
本项目没有额外变量配置；JSONC 主要依赖 Neovim/LSP，而这个 spec 只写了 `ft="json"`。

它与 jsonls 分工不同：语法插件负责显示，jsonls 负责 schema、诊断、补全等。本项目自动
安装的 Tree-sitter parser 列表没有 JSON，因此 JSON 的基础高亮更依赖此插件/内置 syntax。
用 `:set ft? syntax?` 和 `:scriptnames` 检查加载。

上游：[vim-json](https://github.com/elzr/vim-json)。
