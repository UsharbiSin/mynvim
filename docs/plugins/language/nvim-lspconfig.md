[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# nvim-lspconfig：语言服务器与代码导航

**仓库：** `neovim/nvim-lspconfig`。作为 Mason 依赖加载。实际逻辑在 [config/lsp.lua](../../../lua/config/lsp.lua)，服务器细节在根目录 [lsp/](../../../lsp)。

## 架构与已启用功能

本项目使用 Neovim 原生 `vim.lsp.config` / `vim.lsp.enable`。nvim-lspconfig 提供服务器默认配置，根目录 `lsp/*.lua` 补充或覆盖它们，Mason 负责安装进程，nvim-cmp 显示补全候选。历史 `config/coc.lua` 不在当前启动链中。

| 服务 | 对应源码 | 本项目特点 |
| --- | --- | --- |
| clangd | [clangd.lua](../../../lsp/clangd.lua) | C/C++/Objective-C/CUDA；支持头文件切换与符号信息命令 |
| html | [html.lua](../../../lsp/html.lua) | HTML 服务 |
| jsonls | [jsonls.lua](../../../lsp/jsonls.lua) | JSON/JSONC，启用服务器格式化能力 |
| lua_ls | [lua_ls.lua](../../../lsp/lua_ls.lua) | Lua code lens、inlay hint 设置，搭配 lazydev |
| pylsp | [pylsp.lua](../../../lsp/pylsp.lua) | Jedi，声明 isort、flake8、mypy；禁用 pycodestyle |
| sqls | [sqls.lua](../../../lsp/sqls.lua) | 四组 MySQL 环境变量连接，关闭自身诊断与格式化 |

服务器能力仍取决于外部程序、项目依赖及配置。启用 `flake8`、`mypy` 的布尔值不会自动安装对应 pylsp 扩展；应在 **运行 pylsp 的 Python 环境** 中确认插件可用。尤其本项目写的是 `plugins.mypy`，常见的 pylsp-mypy 扩展使用 `plugins.pylsp_mypy`，不能假定当前已经有类型检查。[pylsp-mypy 配置](https://github.com/python-lsp/pylsp-mypy)

## 快捷键

下表只在 LSP 成功附着的缓冲区安装；`<leader>` 是空格。

| 按键 | 功能 |
| --- | --- |
| `gd` / `gr` / `gi` / `gy` | 定义 / 引用 / 实现 / 类型定义 |
| `gD` | 按窗口宽高选择水平或垂直分屏，再跳转定义 |
| `K` | 悬浮文档 |
| `空格 rn` / `空格 ca` | 重命名 / 代码操作 |
| `[g` / `]g` | 上一处 / 下一处诊断 |
| `空格 lf` | 调用 LSP 格式化；与 Conform 的 `空格 fm` 不同 |
| `[f` / `]f` | 跳到当前包含光标的最内层文档符号首行 / 尾行 |
| `空格 th` | 服务器支持时才提供：切换内联提示 |

`[f`、`]f` 的源码按 documentSymbol 范围寻找符号，没有过滤成“仅函数”；在类等符号内也可能跳到其边界，请勿理解为上一个/下一个函数。

支持折叠范围的服务器附着时会把当前窗口设为 LSP 表达式折叠，默认展开（foldlevel=99）。停留光标约 300ms 会展示诊断浮窗，支持的服务器还会高亮同一符号。使用 `zc` / `zo` 折叠和展开；不是每个服务器都提供这些能力。

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

## 平台差异与已知限制

main 关闭诊断行尾文本，只保留符号、下划线和浮窗；windows 启用行尾文本，并使用
Neovim 0.12 的接口显式启用 semantic tokens。Windows 实机已确认 clangd、html、jsonls、
lua_ls、pylsp 与 sqls 均能附着；工程工具链和 SQL 网络连接仍需按项目验证。

本项目没有统一调用 `cmp_nvim_lsp.default_capabilities()`，也没有配置补全 snippet 展开器，复杂补全能力需另见 [cmp-nvim-lsp](cmp-nvim-lsp.md)。SQL 命令注册可能被自定义回调覆盖，详见 [sqls.nvim](sqls.nvim.md)。

更新插件前检查锁定版本的 Neovim 要求；不要直接把旧教程的 `require("lspconfig").xxx.setup()` 与本配置混用。[nvim-lspconfig 上游说明](https://github.com/neovim/nvim-lspconfig)
