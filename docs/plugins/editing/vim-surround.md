[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-surround：成对符号编辑

仓库：`tpope/vim-surround`，VeryLazy 加载，无自定义设置。常用操作：`cs"'` 把双引号换成
单引号，`ds)` 删除圆括号，普通模式 `ysiw]` 给当前单词加方括号，可视模式选择后 `S"`
添加双引号。

命令组合遵循 operator + text object，实际行为见 `:help surround`。它是旧 Vimscript 版本，
不要套用其他 Lua surround 插件的键位。映射冲突时用 `:verbose nmap cs`。

上游：[vim-surround](https://github.com/tpope/vim-surround)。
