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

每组都有 `DB_USER_<后缀>`、`DB_PASSWORD_<后缀>`、`DB_HOST_<后缀>`、`DB_PORT_<后缀>`、`DB_NAME_<后缀>`。这些是作者环境约定，不是可直接使用的公共数据库；请将连接列表改成自己的连接，删除不需要的组。环境变量必须在启动 Neovim 前设置，缺项会形成无效 DSN 或启动错误。

例如 Bash 使用 `export DB_HOST_TY='127.0.0.1'`，PowerShell 使用 `$env:DB_HOST_TY='127.0.0.1'`；其余四项同理，密码应在自己的本地环境管理，不写进仓库。Linux 已运行的 Neovim 和 Windows 已打开的终端不会自动继承后来修改的环境变量。

## 当前集成限制：先检查命令是否注册

本地锁定 sqls.nvim 通过自身 `lsp/sqls.lua` 的 `on_attach` 创建 `Sqls*` 缓冲区命令。本项目自己的同名 LSP 文件又声明 `on_attach`，仅用于关闭格式化能力，因此合并后可能覆盖插件的注册逻辑。下面的功能是 **上游支持的目标用法，需先确认命令存在**：

```vim
:lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
:echo exists(':SqlsSwitchConnection')
```

第二条为 0 时，不是快捷键写错；应检查最终 `vim.lsp.config.sqls.on_attach` 与插件回调是否组合执行。修复需保留插件原有命令注册，同时关闭格式化，本文没有修改配置。[上游 SQL 客户端说明](https://github.com/nanotee/sqls.nvim)

## 命令与操作顺序

| 按键或命令 | 功能 |
| --- | --- |
| `空格 swc` / `:SqlsSwitchConnection` | 选择连接 |
| `空格 swd` / `:SqlsSwitchDatabase` | 选择数据库 |
| `:SqlsShowConnections` | 查看连接 |
| `:SqlsShowDatabases` | 查看数据库 |
| `:SqlsShowTables` | 查看表 |
| `:SqlsExecuteQuery` | 执行当前缓冲区查询 |
| 可视行选中后 `:'<,'>SqlsExecuteQuery` | 执行选中行 |
| `:SqlsExecuteQueryVertical` | 纵向显示结果 |

第一次连通测试使用 `SELECT 1;`，先明确当前连接再执行自己的 SQL。查询命令会真正发送语句到数据库，不只是语法检查。没有另外设置“执行 SQL”快捷键；切换键虽全局存在，底层命令要在 SQL 客户端附着后才可能可用。

## 诊断与平台说明

项目关闭 sqls 的格式化与 publishDiagnostics，分别交给 [Conform](conform.nvim.md)、[nvim-lint](nvim-lint.md)。SQL 补全和表结构信息仍需要有效连接。

两分支连接方式相同，Windows 11 未实机测试。无候选时先区分 SQL 服务器进程未启动、环境变量缺失、连接网络不可达、账号权限不足与插件命令未注册；不要输出整个 DSN 排错，以免把密码写入日志。
