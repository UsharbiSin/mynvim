[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# dadbod-grip.nvim：可编辑数据库表格

仓库：`joryeugene/dadbod-grip.nvim`。按 `<Space>sg` 或执行 `:GripConnect` 打开数据库连接
选择器和工作区。插件要求 Neovim 0.10 以上；MySQL 连接还要求 `mysql.exe` 位于 `PATH`。

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

## 编辑并保存

1. 按 `<Space>sg`，选择连接。
2. 在左侧结构树选择一张表并按回车，打开可编辑网格。
3. 把光标移到单元格，按 `i` 或回车编辑，再按回车暂存该值。
4. 按 `gs` 查看所有暂存修改生成的 SQL。
5. 在 SQL 审核窗口按 `a`，用一个事务提交修改。

网格中按 `u` 撤销一次暂存修改，按 `U` 丢弃全部暂存修改。生产数据库的真正保护仍应依靠
只读账号或数据库权限。JOIN、聚合以及无法唯一定位原始行的查询结果不能安全地直接回写；
需要修改数据时应从结构树打开原始表。

上游：[dadbod-grip.nvim](https://github.com/joryeugene/dadbod-grip.nvim)。
