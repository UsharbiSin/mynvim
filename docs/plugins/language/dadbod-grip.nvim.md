[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# dadbod-grip.nvim：可编辑数据库表格

仓库：`joryeugene/dadbod-grip.nvim`。按 `<Space>sg` 或执行 `:GripConnect` 打开数据库连接
选择器和工作区。插件随 Neovim 启动加载，因此可以直接运行健康检查，不必先打开工作区。
插件要求 Neovim 0.10 以上；MySQL 连接还要求相应客户端位于 `PATH`，Windows 命令名为
`mysql.exe`，Linux 命令名为 `mysql`。

两个分支使用同一套配置。目前 Windows 已实测；Linux 后续需要安装提供 `mysql` 命令的
客户端包，再验证连接、查询结果网格与事务提交。

## 连接

配置在 `lua/config/dadbod-grip.lua`，复用 SQLS 的 `TY`、`TYTEST`、`ST`、`STTEST` 四组
`DB_*` 环境变量。只有五项变量完整的连接才会显示。连接 URL 保存的是 `${VAR}` 占位符，
Grip 执行数据库命令时才展开，因此密码不会写进仓库。

可用以下命令检查客户端与插件状态：

```powershell
mysql.exe --version
```

```vim
:checkhealth dadbod-grip
```

使用 MySQL 时看到 `mysql found` 即表示所需客户端可用。`psql`、`duckdb`、`sqlcmd` 未安装的
警告只影响各自的数据库适配器；本配置已关闭 Grip AI，因此没有 AI provider 的警告也不影响
数据库浏览和编辑。

### Windows 安装 mysql.exe

1. 打开 [MySQL Community Downloads](https://dev.mysql.com/downloads/)，下载 Windows 的
   MySQL Community Server 8.4 MSI 并运行。Oracle 官方推荐使用 MSI 和随附的 MySQL
   Configurator。
2. 只需要连接远程数据库时，在安装向导中使用 `Custom`，确保安装包含 MySQL
   Command-Line Client 的客户端程序；不需要在本机创建或启动 MySQL Server 服务。需要本地
   数据库时则按向导配置 Server。
3. 安装完成后找到 `mysql.exe`。MSI 默认目录通常是：

   ```text
   C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe
   ```

4. 把对应的 `bin` 目录加入 Windows 用户或系统 `Path`：打开“编辑系统环境变量”→“环境
   变量”→选择 `Path`→“新建”，加入：

   ```text
   C:\Program Files\MySQL\MySQL Server 8.4\bin
   ```

5. 关闭已经打开的终端和 Neovim，重新打开 PowerShell 后验证：

   ```powershell
   Get-Command mysql.exe
   mysql.exe --version
   ```

若安装时修改了目标目录，以实际的 `bin` 路径为准。`Get-Command` 仍找不到程序时，可以先用
完整路径运行 `& 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe' --version`，确认
文件存在，再检查 `Path`。官方安装说明见
[Installing MySQL on Microsoft Windows](https://dev.mysql.com/doc/refman/8.4/en/windows-installation.html)。

### Windows MySQL 客户端字符集

Neovim 和 `.sql` 文件使用 UTF-8。Windows 下 `mysql.exe` 的客户端字符集如果
不是 `utf8mb4`，Dadbod Grip 执行包含中文字符串的查询时可能出现：

```text
ERROR 1267 (HY000): Illegal mix of collations
(utf8mb4_general_ci,IMPLICIT) and (gbk_chinese_ci,COERCIBLE)
```

本机使用的 MySQL 8.0 客户端会按以下位置依次查找配置文件：

```text
C:\Windows\my.ini
C:\Windows\my.cnf
C:\my.ini
C:\my.cnf
C:\Program Files\MySQL\my.ini
C:\Program Files\MySQL\my.cnf
```

推荐创建：

```text
C:\Program Files\MySQL\my.ini
```

内容：

```ini
[client]
default-character-set=utf8mb4
```

配置后执行：

```powershell
mysql.exe --print-defaults
```

正常应包含：

```text
--default-character-set=utf8mb4
```

也可以检查当前 `mysql.exe` 实际使用的默认配置文件搜索路径：

```powershell
mysql.exe --help | findstr /C:"Default options" /C:"my.ini" /C:"my.cnf"
```

## 编辑并保存

1. 按 `<Space>sg`，选择连接。
2. 在左侧结构树选择一张表并按回车，打开可编辑网格。
3. 把光标移到单元格，按 `i` 或回车编辑，再按回车暂存该值。
4. 按 `gs` 查看所有暂存修改生成的 SQL。
5. 在 SQL 审核窗口按 `a`，用一个事务提交修改。

网格中按 `u` 撤销一次暂存修改，按 `U` 丢弃全部暂存修改。生产数据库的真正保护仍应依靠
只读账号或数据库权限。JOIN、聚合以及无法唯一定位原始行的查询结果不能安全地直接回写；
需要修改数据时应从结构树打开原始表。


## 使用方式

当前配置把数据库操作分成两类：

| 按键 | 功能 |
| --- | --- |
| `<Space>sg` | 打开 Dadbod Grip 数据库工作区，用于浏览结构和编辑表格 |
| `<Space>st` | 打开带表注释和列注释的数据库侧栏 |
| `K` | 在 Grip 查询结果中显示光标所在字段的类型和注释 |
| `<Space>sc` | 为当前 `.sql` 缓冲区选择数据库连接，不离开当前文件 |
| `<Space>sr` | 普通模式执行整个 `.sql` 缓冲区 |
| `<Space>sr` | 可视模式执行选中的 SQL |

### Dadbod Grip 工作区

按 `<Space>sg` 或执行：

```vim
:GripConnect
```

### 中文注释侧栏

`<Space>st` 使用当前 SQL 缓冲区选择的连接；尚未选择时会先显示连接列表。侧栏通过 MySQL
`information_schema.TABLES` 和 `information_schema.COLUMNS` 一次读取表与字段注释。
注释用 `Comment` 高亮显示，终端 Neovim 无法只缩小其中一段文字的字体。

| 侧栏按键 | 功能 |
| --- | --- |
| `Enter` | 用 Grip 打开当前表 |
| `l` / `h` | 展开/收起字段 |
| `/` / `F` | 按表名、表注释、字段名或字段注释筛选/清除 |
| `K` | 显示当前表的完整注释 |
| `r` | 忽略缓存并重新读取注释 |
| `q` / `Esc` | 关闭侧栏 |

查询结果中把光标放在目标列并按 `K`，显示该字段的类型和注释。此缓冲区映射替换 Grip
原有的 `K` 行详情；普通代码缓冲区的 LSP `K` 不受影响。此注释功能目前针对 MySQL
元数据设计。

`空格 sr` 打开的查询结果还增加以下缓冲区快捷键：

| 按键 | 功能 |
| --- | --- |
| `Ctrl-h` / `Ctrl-l` | 将光标所在列向左或向右移动，并让光标跟随该列 |
| `Ctrl-s` | 按光标所在列升序排列 |
| `Ctrl-d` | 按光标所在列降序排列 |

列移动只改变当前结果网格的显示顺序，不会修改 SQL、数据库字段顺序或数据。排序会替换
原有排序条件并重新查询当前结果；存在尚未提交的单元格修改时，会先询问是否放弃修改。
这些映射只在结果网格中覆盖全局 `Ctrl-s` 保存和普通模式 `Ctrl-d` 向下滚动半页。

上游：[dadbod-grip.nvim](https://github.com/joryeugene/dadbod-grip.nvim)。
