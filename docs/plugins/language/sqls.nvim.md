[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# sqls.nvim：SQL 连接切换与查询结果

**仓库：** `nanotee/sqls.nvim`。启动时声明加载；外部 `sqls` 由 Mason 安装。项目连接配置见 [lsp/sqls.lua](../../../lsp/sqls.lua)，切换键见 [keymaps.lua](../../../lua/core/keymaps.lua)。

## 连接配置

项目定义四个 MySQL 连接，每个从五个环境变量拼接 DSN：

| 连接别名 | 五个环境变量的后缀 |
| --- | --- |
| `tongyan` | `TY` |
| `tongyan_test` | `TYTEST` |
| `platform_st` | `ST` |
| `platform_st_test` | `STTEST` |

每组都有 `DB_USER_<后缀>`、`DB_PASSWORD_<后缀>`、`DB_HOST_<后缀>`、`DB_PORT_<后缀>`、`DB_NAME_<后缀>`。这些是作者环境约定，不是可直接使用的公共数据库；请将连接列表改成自己的连接，删除不需要的组。环境变量必须在启动 Neovim 前设置；任一项缺失时整组连接会被省略，SQLS 仍可启动。

例如 Bash 使用 `export DB_HOST_TY='127.0.0.1'`，PowerShell 使用 `$env:DB_HOST_TY='127.0.0.1'`；其余四项同理，密码应在自己的本地环境管理，不写进仓库。Linux 已运行的 Neovim 和 Windows 已打开的终端不会自动继承后来修改的环境变量。

## 命令注册与格式化职责

本地锁定 sqls.nvim 通过自身 `lsp/sqls.lua` 的 `on_attach` 创建 `Sqls*` 缓冲区命令。SQLS
自带格式化器会激进展开 `FROM`、`JOIN` 和 `IN`，部分查询还可能返回错误的文本编辑，因此配置
关闭其文档与范围格式化能力。SQL 缓冲区的普通模式和可视模式 `空格 lf` 改由 SQLFluff
处理；其他语言的 `空格 lf` 仍调用对应 LSP。可用以下命令检查当前状态：

```vim
:lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
:echo exists(':SqlsSwitchConnection')
```

Windows 专项测试会确认 SQLS 无数据库连接时能附着、第二条命令已注册，且 SQLS 格式化能力
已经关闭。第二条为 0 时先确认当前是 SQL buffer 且客户端已经附着。
[上游 SQL 客户端说明](https://github.com/nanotee/sqls.nvim)

## 命令与操作顺序

| 按键或命令 | 功能 |
| --- | --- |
| `空格 swc` / `:SqlsSwitchConnection` | 选择连接 |
| `空格 swd` / `:SqlsSwitchDatabase` | 选择数据库 |
| `空格 ssc` / `:SqlsShowConnections` | 查看连接列表 |
| `空格 ssd` / `:SqlsShowDatabases` | 查看数据库列表 |
| `空格 sst` / `:SqlsShowTables` | 查看数据表 |
| 普通模式 `空格 se` / `:SqlsExecuteQuery` | 执行整个 SQL 缓冲区 |
| 可视行模式 `空格 se` | 执行选中的 SQL 行 |
| 普通模式 `空格 sv` / `:SqlsExecuteQueryVertical` | 纵向显示整个缓冲区的查询结果 |
| 可视行模式 `空格 sv` | 纵向显示选中 SQL 行的查询结果 |

第一次连通测试使用 `SELECT 1;`，先明确当前连接再执行自己的 SQL。查询命令会真正发送语句到数据库，不只是语法检查。以上快捷键只在 `sql` 或 `mysql` 缓冲区中创建；底层命令要在 SQL 客户端附着后才可用。可视模式执行只支持按行选择。

## 诊断与平台说明

项目关闭 sqls 的 publishDiagnostics 和格式化能力，诊断交给 [nvim-lint](nvim-lint.md)；
`空格 lf` 与 `空格 fm` 都使用 [Conform](conform.nvim.md) 的 SQLFluff 格式化。SQL 补全和
表结构信息仍需要有效连接。

Windows 11 已实测 SQLS 在没有数据库环境变量时仍能附着；真实数据库网络未测试。无候选时先区分 SQL 服务器进程未启动、环境变量缺失、连接网络不可达、账号权限不足与插件命令未注册；不要输出整个 DSN 排错，以免把密码写入日志。
