[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# nvim-lspconfig：语言服务器与代码导航

**仓库：** `neovim/nvim-lspconfig`。作为 Mason 依赖加载。实际逻辑在 [config/lsp.lua](../../../lua/config/lsp.lua)，服务器细节在根目录 [lsp/](../../../lsp)。

## 架构与已启用功能

本项目使用 Neovim 原生 `vim.lsp.config` / `vim.lsp.enable`。nvim-lspconfig 提供服务器默认配置，根目录 `lsp/*.lua` 补充或覆盖它们，Mason 负责安装进程，nvim-cmp 显示补全候选。历史 `config/coc.lua` 不在当前启动链中。

| 服务 | 对应源码 | 本项目特点 |
| --- | --- | --- |
| clangd | [clangd.lua](../../../lsp/clangd.lua) | C/C++/Objective-C/CUDA；支持头文件切换与符号信息命令 |
| html | [html.lua](../../../lsp/html.lua) | HTML 服务 |
| jdtls | nvim-lspconfig 默认配置 | Java；仅检测到 Java 21 或更高版本时启动 |
| jsonls | [jsonls.lua](../../../lsp/jsonls.lua) | JSON/JSONC，启用服务器格式化能力 |
| lua_ls | [lua_ls.lua](../../../lsp/lua_ls.lua) | Lua code lens、inlay hint 设置，搭配 lazydev |
| pylsp | [pylsp.lua](../../../lsp/pylsp.lua) | Jedi，声明 isort、flake8、mypy；禁用 pycodestyle |
| sqls | [sqls.lua](../../../lsp/sqls.lua) | 四组 MySQL 环境变量连接，关闭自身诊断并保留格式化 |
| ts_ls | nvim-lspconfig 默认配置 | JavaScript/TypeScript 诊断与语言功能 |

服务器能力仍取决于外部程序、项目依赖及配置。启用 `flake8`、`mypy` 的布尔值不会自动安装对应 pylsp 扩展；应在 **运行 pylsp 的 Python 环境** 中确认插件可用。尤其本项目写的是 `plugins.mypy`，常见的 pylsp-mypy 扩展使用 `plugins.pylsp_mypy`，不能假定当前已经有类型检查。[pylsp-mypy 配置](https://github.com/python-lsp/pylsp-mypy)

## 快捷键

下表只在 LSP 成功附着的缓冲区安装；`<leader>` 是空格。

| 按键 | 功能 |
| --- | --- |
| `gd` / `gr` / `gi` / `gy` | 定义 / 引用 / 实现 / 类型定义 |
| `gD` | 按窗口宽高选择水平或垂直分屏，再跳转定义 |
| `K` | 悬浮文档；安装 LspProxy 后自动翻译为中文 |
| `空格 rn` / `空格 ca` | 重命名 / 代码操作 |
| `[g` / `]g` | 上一处 / 下一处诊断 |
| 普通模式 `空格 lf` | 使用当前缓冲区所有支持文档格式化的 LSP 格式化全文 |
| 可视模式 `空格 lf` | 使用支持范围格式化的 LSP 只格式化选中范围；不支持时提示且不改全文 |
| `[f` / `]f` | 跳到当前包含光标的最内层文档符号首行 / 尾行 |
| `空格 th` | 服务器支持时才提供：切换内联提示 |

`[f`、`]f` 的源码按 documentSymbol 范围寻找符号，没有过滤成“仅函数”；在类等符号内也可能跳到其边界，请勿理解为上一个/下一个函数。

配置检测到 [LspProxy](lsp-proxy.md) 后，会让已配置的语言服务器通过代理启动。`K` 返回的英文
说明会翻译为中文；函数签名、类型名和代码块保持原样。未安装代理时直接启动原语言服务器。

支持折叠范围的服务器附着时会把当前窗口设为 LSP 表达式折叠，按函数、class 和代码块等
语法结构生成折叠；没有对应 LSP 或 LSP 退出后自动回退到 Tree-sitter。折叠默认展开
（foldlevel=99），使用 `zc` / `zo` 折叠和展开。两个系统都显示行尾 virtual text；
停留光标约 300ms 还会展示诊断浮窗，支持的服务器会高亮同一符号。

## 首次验证

1. `:Mason` 确认对应服务完成安装。
2. 从实际项目打开文件；Python 建议先激活项目环境。C/C++ 应提供正确的 `compile_commands.json` 或编译选项。
3. 执行以下只读诊断，确认有客户端附着，再测试 `K`、`gd` 和重命名。

```vim
:checkhealth vim.lsp
:lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
:lua print(vim.fn.exepath("clangd"))
:LspLog
```

clangd 成功附着后可用 `:LspClangdSwitchSourceHeader` 和 `:LspClangdShowSymbolInfo`。窗口跳转后用原生 `Ctrl-o` 返回。
配置会动态查找 PATH 中的 `gcc`、`g++`、`clang` 和 `clang++`，允许 clangd 查询实际编译驱动。
没有 `compile_commands.json` 的单文件会额外使用 GCC 报告的目标平台和系统头文件目录，这与
F10 的 GCC/G++ 工具链保持一致；项目提供编译数据库时仍以项目参数为准。

## 平台差异与已知限制

两个系统均启用诊断行尾 virtual text，并使用 Neovim 0.12 的接口显式启用 semantic tokens。
Windows 实机已确认 clangd、html、jsonls、lua_ls、pylsp 与 sqls 均能附着，`ts_ls` 的进程
可启动。当前机器只有 Java 8，因此 `jdtls` 会保持禁用；升级到 Java 21 后需再验证 Java
项目和 Markdown Java 围栏。工程工具链和 SQL 网络连接仍需按项目验证。

本项目没有统一调用 `cmp_nvim_lsp.default_capabilities()`，也没有配置补全 snippet 展开器，复杂补全能力需另见 [cmp-nvim-lsp](cmp-nvim-lsp.md)。SQL 命令注册可能被自定义回调覆盖，详见 [sqls.nvim](sqls.nvim.md)。

更新插件前检查锁定版本的 Neovim 要求；不要直接把旧教程的 `require("lspconfig").xxx.setup()` 与本配置混用。[nvim-lspconfig 上游说明](https://github.com/neovim/nvim-lspconfig)
