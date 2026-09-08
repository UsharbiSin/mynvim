[返回项目使用说明](../README.md) · [SQLS 插件说明](plugins/language/sqls.nvim.md)

# Windows 配置 SQL 数据库连接

当前 Neovim 配置通过 SQLS 连接 MySQL。连接信息从环境变量读取，不在仓库中保存账号和密码。

## 1. 设置连接参数

在启动 Neovim 的同一个 PowerShell 窗口中设置：

```powershell
$env:DB_USER_TY = 'root'
$env:DB_PASSWORD_TY = '你的密码'
$env:DB_HOST_TY = '127.0.0.1'
$env:DB_PORT_TY = '3306'
$env:DB_NAME_TY = '数据库名'

nvim query.sql
```

同一连接的五个变量必须全部设置，并且不能为空；缺少任意一项时，该连接不会传给 SQLS。
修改环境变量后，需要完全退出 Neovim，再从设置变量的 PowerShell 中重新启动。

## 2. 当前连接名称

配置文件 [lsp/sqls.lua](../lsp/sqls.lua) 预置了四个连接：

| 连接名称 | 环境变量后缀 | 必需变量示例 |
| --- | --- | --- |
| `tongyan` | `TY` | `DB_USER_TY`、`DB_PASSWORD_TY`、`DB_HOST_TY`、`DB_PORT_TY`、`DB_NAME_TY` |
| `tongyan_test` | `TYTEST` | `DB_USER_TYTEST` 等五项 |
| `platform_st` | `ST` | `DB_USER_ST` 等五项 |
| `platform_st_test` | `STTEST` | `DB_USER_STTEST` 等五项 |

例如配置 `tongyan_test`：

```powershell
$env:DB_USER_TYTEST = 'root'
$env:DB_PASSWORD_TYTEST = '你的密码'
$env:DB_HOST_TYTEST = '127.0.0.1'
$env:DB_PORT_TYTEST = '3306'
$env:DB_NAME_TYTEST = '测试数据库名'
```

## 3. 检查 SQLS

进入 Neovim 后确认 Mason 已安装 SQLS：

```vim
:Mason
```

如果尚未安装：

```vim
:MasonInstall sqls
```

打开 `.sql` 文件后检查 LSP 和连接：

```vim
:lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
:SqlsShowConnections
```

连接列表为空时，先检查五个环境变量是否全部存在，并确认 Neovim 是从设置变量后的 PowerShell
启动的。

## 4. 选择连接和数据库

| 按键或命令 | 功能 |
| --- | --- |
| `空格 swc` / `:SqlsSwitchConnection` | 选择数据库连接 |
| `空格 swd` / `:SqlsSwitchDatabase` | 选择数据库 |
| `空格 ssc` / `:SqlsShowConnections` | 显示连接列表 |
| `空格 ssd` / `:SqlsShowDatabases` | 显示数据库列表 |
| `空格 sst` / `:SqlsShowTables` | 显示数据表 |
| `空格 st` | 打开带表/列中文注释的侧栏 |

## 5. 测试和执行 SQL

先执行无副作用的连通测试：

```sql
SELECT 1;
```

普通模式按 `空格 se`，或执行命令，运行整个 SQL 缓冲区：

```vim
:SqlsExecuteQuery
```

可视行模式选中部分 SQL 后按 `空格 se`，等价于：

```vim
:'<,'>SqlsExecuteQuery
```

普通模式按 `空格 sv` 纵向显示整个缓冲区的查询结果；可视行模式按 `空格 sv` 只执行并纵向
显示选中行。对应命令为：

```vim
:SqlsExecuteQueryVertical
```

## 6. Dadbod Grip 可视化数据库工作区

按 `空格 sg` 打开 Dadbod Grip 连接选择器。

Dadbod Grip 会打开独立的 `grip://` 工作区，用于：

- 浏览数据库结构；
- 打开和编辑原始表；
- 暂存单元格修改；
- 审核生成的 SQL；
- 在事务中提交修改。

按 `空格 st` 可直接打开左侧“表与注释”栏。它从 MySQL `information_schema` 读取
`TABLE_COMMENT` 和 `COLUMN_COMMENT`，并按连接缓存：

- 表名后以 Comment 颜色显示表注释；
- `l` / `h` 展开或收起字段，字段后显示类型和列注释；
- `/` 输入技术表名、中文表名或字段注释进行筛选，`F` 清除筛选；
- `K` 查看当前表的完整表/列注释，`r` 重新读取元数据；
- `Enter` 用 Dadbod Grip 打开表，继续编辑和保存数据。

执行 `空格 sr` 并进入 Grip 查询结果后，把光标放在目标列并按 `K`，即可显示该字段
的类型和数据库注释。普通单表结果会限定当前表；JOIN 或自定义查询会列出该字段的所有同名
来源。此映射只覆盖 Grip 网格中的原有 `K` 行详情，普通代码缓冲区仍使用 LSP 悬浮文档。
查询结果中还可按 `Ctrl-h` / `Ctrl-l` 左移或右移当前列；按 `Ctrl-s` 根据当前列升序排列，
按 `Ctrl-d` 降序排列。列移动只调整当前网格的显示，排序则会替换排序条件并重新查询结果。

如果只希望继续留在当前 `.sql` 文件中执行查询，应使用 `空格 sc` +
`空格 sr`，而不是 `空格 sg`。

Windows 配置关闭了 Docker 自动发现，以避免连接选择器因同步 Docker
探测阻塞 Neovim。预先配置的四组 MySQL 连接不受影响。

## 7. 常见问题

- `:SqlsShowConnections` 为空：同一后缀的五个环境变量不完整，或 Neovim 没有继承环境变量。
- 找不到 `Sqls*` 命令：确认当前文件扩展名为 `.sql`，并检查 SQLS 是否已经附着。
- 无法连接：分别检查主机、端口、账号、密码、数据库名称、网络和 MySQL 账号权限。
- 没有补全或表结构：先确认连接成功；SQLS 启动成功不代表数据库已经连通。
- 表或列没有中文注释：确认建表语句已设置 `COMMENT`，且账号可以读取 `information_schema`。
- 使用 PostgreSQL 或 SQLite：当前 `driver` 固定为 `mysql`，需要修改 `lsp/sqls.lua` 的驱动和 DSN。

不要把真实密码直接写入仓库、Lua 配置或提交记录。
