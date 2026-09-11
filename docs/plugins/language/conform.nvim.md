[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# conform.nvim：手动调用外部格式化器

**仓库：** `stevearc/conform.nvim`。按 `空格 fm` 或执行 `:ConformInfo` 时加载；配置在 [conform.lua](../../../lua/config/conform.lua)。

## 本项目格式化规则

| 文件类型 | 外部格式化器 |
| --- | --- |
| Python | 先 `isort` 排序导入，再 `black` |
| SQL | `sqlfluff`（MySQL 方言；`空格 lf` 与 `空格 fm`） |
| JavaScript、HTML、CSS、JSON、Markdown | `prettier` |
| Lua | `stylua` |

`mysql`、`vimwiki`、`jsonc`、C/C++ 未在本表登记。扩展名为 .md 但实际 filetype 是 vimwiki 时，不会因为扩展名自动走 Markdown formatter。用 `:set filetype?` 检查。

`:w` 只写入文件，不触发 Conform 或 LSP 格式化。手动 `空格 fm` 支持普通/可视模式，设置
`lsp_fallback=true`；当前文件没有已配置的外部格式化器时才尝试 LSP。SQLFluff 在复杂查询
上可能需要数秒，因此 SQL 的 `空格 lf` 和 `空格 fm` 异步执行，不会受同步格式化超时限制；
其他格式化器同步执行，超时 3000ms。

## 安装与首次使用

```vim
:MasonInstall isort black prettier stylua sqlfluff
:ConformInfo
```

Conform 只调用工具，不负责安装。Mason 完成后确认 `:ConformInfo` 中当前文件的 formatter 可用。按空格 fm 测试整个文件；也可视选择若干行后尝试范围格式化，具体支持由 formatter 决定。

`空格 fm` 本身会加载插件。LSP 的 `空格 lf` 通常只使用当前文件已附着且声明支持相应格式化
方式的语言服务器；SQLS 不提供可靠的格式化结果，所以 SQL 的 `空格 lf` 会改用 SQLFluff。
普通模式格式化全文，可视模式只格式化选中范围。

## 项目配置文件

Black、isort、Prettier、StyLua 和 SQLFluff 可读取各自的项目配置。优先把团队格式写在项目根
目录相应配置文件中，而非全部写死到个人 Neovim 配置。SQLFluff 的检查和格式化均固定使用
MySQL 方言，并在 Windows 上显式使用 UTF-8 处理中文 SQL。

SQL 项目可添加如下 `.sqlfluff`（示意，需按实际 SQL 方言选择）：

```ini
[sqlfluff]
dialect = mysql
```

## 排错与平台

用 `:ConformInfo` 查看程序和日志，用 `:lua print(vim.fn.exepath("prettier"))` 查 Neovim 的 PATH。手动格式化结果不同时，先用 `:verbose nmap <leader>lf` 与 `:verbose nmap <leader>fm` 确认调用的是 LSP 还是 Conform，再检查对应服务器或项目工具配置。Windows 实机可解析 black、isort 与 sqlfluff；prettier、stylua 仍需安装。[Conform 上游说明](https://github.com/stevearc/conform.nvim)
