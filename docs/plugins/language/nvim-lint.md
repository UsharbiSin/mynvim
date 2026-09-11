[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# nvim-lint：SQLFluff 异步诊断

**仓库：** `mfussenegger/nvim-lint`。在 `BufReadPre` 或 `BufNewFile` 时加载；配置见 [nvim-lint.lua](../../../lua/config/nvim-lint.lua)。

## 当前只检查 SQL

项目的 `linters_by_ft` 仅为 `sql` 和 `mysql` 配置 `sqlfluff`。虽上游可适配多种检查器，本项目没有通过它检查 Python、JavaScript 等语言。

调用参数为：

```text
sqlfluff lint --format=json --dialect=mysql --exclude-rules=AM05,RF05,ST06 -
```

SQL 内容经标准输入传递，方言固定为 MySQL。进入缓冲区、保存后、退出插入模式分别通过 `BufEnter`、`BufWritePost`、`InsertLeave` 自动触发；结果转为 Neovim 诊断。

配置关闭三条不会影响 SQL 执行的主观风格规则：`AM05` 不再强制把 `JOIN` 写成
`INNER JOIN`，`RF05` 允许反引号包裹的展示型中文别名，`ST06` 不再强制调整 SELECT 字段顺序。
语法错误、歧义字段、引用错误和文件格式等诊断继续保留。

## 首次使用

```vim
:MasonInstall sqlfluff
:lua print(vim.fn.exepath("sqlfluff"))
```

打开 .sql 文件后检查 `:set filetype?`，输入带格式/语法问题的 MySQL 查询，离开插入模式，查看符号和下划线。可用以下命令手动检查与查看诊断：

```vim
:lua require("lint").try_lint()
:lua vim.diagnostic.open_float()
:lua vim.diagnostic.setqflist()
```

项目 `[g`、`]g` 映射是在 LspAttach 才创建；若 SQL LSP 没有成功附着，不能假设这两个键仍已定义，即使 lint 本身能运行。

## 方言、格式化与排错

它只诊断，不修复；[Conform](conform.nvim.md) 可由 `空格 fm` 手动执行 SQLFluff 格式化。两个插件的参数是分别配置的，lint 的 MySQL 方言不会传给 formatter。PostgreSQL、SQLite 项目需调整这里的参数以及项目 `.sqlfluff`。

若没有诊断，确认 sqlfluff 的 PATH 和 filetype，检查 `:messages`。如果产生重复消息，检查用户额外启用的 SQL LSP 检查器；本项目已经关闭 sqls 自身诊断。Windows 实机已确认配置可加载且能解析到 sqlfluff。[上游使用说明](https://github.com/mfussenegger/nvim-lint)
