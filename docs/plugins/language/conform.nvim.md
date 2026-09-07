[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# conform.nvim：保存时与手动格式化

**仓库：** `stevearc/conform.nvim`。在 `BufWritePre`（保存前）或 `:ConformInfo` 时加载；配置在 [conform.lua](../../../lua/config/conform.lua)。

## 本项目格式化规则

| 文件类型 | 外部格式化器 |
| --- | --- |
| Python | 先 `isort` 排序导入，再 `black` |
| SQL | `sqlfluff` |
| JavaScript、HTML、CSS、JSON、Markdown | `prettier` |
| Lua | `stylua` |

`mysql`、`vimwiki`、`jsonc`、C/C++ 未在本表登记。扩展名为 .md 但实际 filetype 是 vimwiki 时，不会因为扩展名自动走 Markdown formatter。用 `:set filetype?` 检查。

保存时等待最多 3000ms，`lsp_fallback=false`；因此外部格式化器缺失时不会自动改走 LSP。手动 `空格 fm` 支持普通/可视模式，设置 `lsp_fallback=true`、同步执行、超时 300ms。这两个超时差别很大，冷启动慢的 Python/Node 工具可能保存时成功、手动时超时。

## 安装与首次使用

```vim
:MasonInstall isort black prettier stylua sqlfluff
:ConformInfo
```

Conform 只调用工具，不负责安装。Mason 完成后确认 `:ConformInfo` 中当前文件的 formatter 可用。保存一次测试格式；可视选择若干行再按空格 fm 尝试范围格式化，具体支持由 formatter 决定。

`空格 fm` 在插件加载后才创建，插件声明没有给这个键单独设置 lazy 触发。因此新会话如果还没保存过，先执行 `:ConformInfo`，再使用该键。LSP 的 `空格 lf` 属于另一条格式化路径。

## 项目配置文件

Black、isort、Prettier、StyLua 和 SQLFluff 可读取各自的项目配置。优先把团队格式写在项目根目录相应配置文件中，而非全部写死到个人 Neovim 配置。SQLFluff **格式化** 没有在本项目强制指定方言；检查器虽固定 MySQL，但不会自动影响 Conform。

SQL 项目可添加如下 `.sqlfluff`（示意，需按实际 SQL 方言选择）：

```ini
[sqlfluff]
dialect = mysql
```

## 排错与平台

用 `:ConformInfo` 查看程序和日志，用 `:lua print(vim.fn.exepath("prettier"))` 查 Neovim 的 PATH。保存结果意外变化时检查同时运行的 LSP formatter 与项目工具配置。Windows 实机可解析 black、isort 与 sqlfluff；prettier、stylua 仍需安装。[Conform 上游说明](https://github.com/stevearc/conform.nvim)
