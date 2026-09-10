[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# nvim-treesitter：语法解析器与结构化高亮

**仓库：** `nvim-treesitter/nvim-treesitter`。本项目使用新版接口，启动时加载，更新构建命令为 `:TSUpdate`。配置见 [nvim-treesitter.lua](../../../lua/config/nvim-treesitter.lua)。

## 当前启用内容

配置调用 `require("nvim-treesitter").install(parsers)` 安装下列 14 个 parser：

`python`、`lua`、`c`、`cpp`、`java`、`vim`、`vimdoc`、`query`、`markdown`、`markdown_inline`、
`latex`、`css`、`html`、`javascript`、`json`、`sql`。`jsonc` 复用 JSON parser。

每次 FileType 事件用 `pcall(vim.treesitter.start, args.buf)` 尝试启用高亮；缺 parser 时安静跳过。Vimwiki 的 filetype 被注册给 Markdown parser。它还服务于 [render-markdown](../markdown/render-markdown.nvim.md) 和 [DAP 变量文本](../debugging/nvim-dap-virtual-text.md)。

项目没有启用旧版 `nvim-treesitter.configs.setup`，代码中的 Treesitter 折叠自动命令已注释，也没有启用 Treesitter 缩进。折叠主要由 LSP 接管。JSON 不在自动 parser 安装列表里，尽管有 JSON 的传统语法插件与 LSP。

## 首次依赖与安装

新接口需要可用的 C 编译器、tar、curl 与 tree-sitter CLI；本地锁定插件 README 指定 CLI 至少 0.26.1。CLI 与 parser 是不同组件，安装 Neovim 不保证两者齐备。上游接口与版本要求可能继续变化，使用项目锁文件并核对安装目录 README。[上游安装要求](https://github.com/nvim-treesitter/nvim-treesitter#requirements)

Arch 安装根目录指南中的编译工具和 tree-sitter CLI。Windows 11 需要原生 Windows 可用的编译器和 CLI；从设置好 PATH 的终端启动 Neovim，不能把 WSL 的 Linux 可执行文件当作原生编译器。

```vim
:checkhealth nvim-treesitter
:TSInstall markdown markdown_inline
:TSUpdate
```

自动安装是异步的，首次打开文件可能早于 parser 完成。安装后重新打开文件或执行 `:lua vim.treesitter.start()` 验证。更新插件后要同步 parser，旧二进制与新 query 不一致可能报错。

## 使用与排错

`:Inspect` 查看光标位置高亮来源；`:InspectTree` 打开语法树；`:lua print(vim.treesitter.language.get_lang(vim.bo.filetype))` 查看 filetype 映射。如果一个冷门文件没有语法树，先看它是否在安装列表内。

本项目的 pcall 会隐藏高亮启动失败，不能因为没有弹错就认定 parser 安装成功。若报 query/ABI/编译错误，先检查 `:checkhealth` 与 `:messages`。Windows 实机已确认配置列出的 14 个 parser 均能加载，Tree-sitter CLI 0.26.12 可用。
