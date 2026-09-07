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
