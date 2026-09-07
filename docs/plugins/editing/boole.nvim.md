[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# boole.nvim：值的递增与递减（仅 main）

仓库：`nat-418/boole.nvim`。仅 main 分支声明，VeryLazy 加载；配置在 main 的
`lua/config/nvim-boole.lua`。普通模式 `Ctrl-a` 向前切换，`Ctrl-x`
向后切换，除布尔值外还增加 `enable` / `disable` 对。

把光标放在 `true`、`false`、`enable` 或 `disable` 上使用；其他上游内置循环以帮助为准。
它覆盖/扩展 Vim 原生 Ctrl-a/Ctrl-x 数字增减语义，并可能与多光标的 Ctrl-x 相邻冲突。
Windows 分支未安装，也没有对应配置文件。

上游：[boole.nvim](https://github.com/nat-418/boole.nvim)。
