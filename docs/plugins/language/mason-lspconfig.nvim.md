[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# mason-lspconfig.nvim：Mason 与 LSP 配置桥接

**仓库：** `williamboman/mason-lspconfig.nvim`（现为 mason-org）。作为 [Mason](mason.nvim.md) 依赖加载；配置在 [mason.lua](../../../lua/config/mason.lua)。

## 当前安装清单

`ensure_installed` 使用 LSP 配置名，而 `:MasonInstall` 使用 Mason 包名。不要把两者混用。

| LSP 配置名 | Mason 包名 | 用途 |
| --- | --- | --- |
| `pylsp` | `python-lsp-server` | Python |
| `html` | `html-lsp` | HTML |
| `jsonls` | `json-lsp` | JSON/JSONC |
| `sqls` | `sqls` | SQL/MySQL |
| `lua_ls` | `lua-language-server` | Lua/Neovim 配置 |
| `clangd` | `clangd` | C/C++/CUDA 等 |

该表反映项目声明，不代表所有语言都已装好。首次启动需等待安装完成，随后查看 `:checkhealth vim.lsp`。

## 当前启用方式与版本注意

项目随后 `require("config.lsp")`，显式调用 `vim.lsp.enable()` 启用上述六项。本地锁定版本属于 v2 接口，桥接插件自身默认还会自动启用 Mason 中安装且受支持的服务器。因此“六项”是项目显式配置的基线；用户曾经额外安装的服务器也可能附着。

配置中的 `automatic_installation = true` 是旧接口字段；本地 v2 文档使用 `ensure_installed` 和 `automatic_enable`。不要用这个旧字段推断“所有 LSP 都会自动下载”。升级或排查时应对照已安装版本。[上游配置与自动启用说明](https://github.com/mason-org/mason-lspconfig.nvim#automatically-enable-installed-servers)

## 使用与扩展

`:LspInstall pylsp` 可以按 LSP 名安装 Python 服务；`:Mason` 可以按包名检查状态。新增语言时，修改 `ensure_installed`，必要时新建 `lsp/<server>.lua`，并在 [lsp.lua](../../../lua/config/lsp.lua) 按本项目习惯显式启用。格式化器和调试适配器不应写进此列表。

JavaScript/TypeScript 通过 `ts_ls` 提供 LSP，Java 通过 `jdtls` 提供 LSP。`jdtls` 要求 Java 21
或更高版本；版本不足时配置不会启动它，避免每次打开 Java 围栏都产生进程错误。PHP 仍然没有
默认 PHP LSP。安装 PIV、vim-javascript 本身不会自动变成语言服务器支持。

## 平台与排错

两个系统使用同一服务列表。Windows 差异主要在 Mason 外部运行时及可执行文件扩展名；
用 `:lua print(vim.fn.exepath("pylsp"))` 检查 Neovim 实际解析到的程序。Windows 实机的六个
服务均已安装并能附着。两个系统当前均使用 Neovim 0.12.5；若报 `vim.lsp.enable` 不存在，
应检查实际启动的 `nvim` 是否仍指向旧程序。
