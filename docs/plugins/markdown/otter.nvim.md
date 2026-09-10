[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# otter.nvim：Markdown 围栏代码 LSP

仓库：`jmbuhr/otter.nvim`。Markdown 和 Vimwiki 文件打开后自动激活。插件根据 Tree-sitter
注入结果，为每种围栏语言建立同步的隐藏缓冲区，并让本项目已配置的语言服务器附着。

例如 `python` 围栏可使用 pylsp 的补全、诊断、悬浮、定义、引用和重命名，`lua`、`c`、
`cpp`、`java`、`javascript`、`html`、`json`、`sql` 围栏同样会尝试连接对应 LSP。语言服务器、Tree-sitter parser
或围栏语言标识缺失时，该语言只保留基础语法高亮。

嵌入式 Python 会过滤 Flake8/pycodestyle 的 `E303`（空行过多），因为 Otter 为保持主文档
行号而填充的空行会让这条规则产生干扰。普通 `.py` 文件仍保留 `E303` 检查，其他诊断不变。

LSP Semantic Tokens 当前不能由 Otter 转发到 Markdown 主缓冲区，因此代码颜色继续由
Tree-sitter 注入提供；LSP 负责语义操作和诊断。这样可避免多个嵌入语言使用不同 token
legend 时发生错色。隐藏缓冲区不会写入磁盘，诊断在保存、离开插入模式和文本变化后更新。

JSON/JSONC、C/C++、Java、JavaScript 和 HTML 均安装对应 Tree-sitter parser。独立 JSON/JSONC
文件的缩进作用域由 `indent-blankline.nvim` 根据 `object` 和 `array` 节点显示。JSON、C/C++、
JavaScript、HTML 分别使用 `jsonls`、`clangd`、`ts_ls`、`html`；Java 使用 `jdtls`，要求
Java 21 或更高版本。Java 版本不满足时仍有围栏高亮，但不会启动 Java 诊断。

在代码块内使用现有的 `K`、`gd`、`gr`、`gi` 和重命名快捷键即可。执行 `:LspInfo` 可看到
当前 Markdown 缓冲区的 `otter-ls[缓冲区号]`；若没有连接，先检查围栏语言名和对应 LSP。

上游：[otter.nvim](https://github.com/jmbuhr/otter.nvim)。
