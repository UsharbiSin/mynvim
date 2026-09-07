[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-multiple-cursors：多光标编辑

仓库：`terryma/vim-multiple-cursors`，VeryLazy 加载，无自定义配置。默认 `Ctrl-n` 选择光标下
单词并寻找下一个匹配，继续按增加光标；`Ctrl-x` 跳过，`Ctrl-p` 回退，Esc 退出多光标模式。

boole.nvim 把普通模式 `Ctrl-x` 用作递减布尔/枚举，多光标激活前后可能有按键语境
差异。该插件较老，复杂操作先保存；用 `:verbose nmap <C-n>` 检查冲突。

上游：[vim-multiple-cursors](https://github.com/terryma/vim-multiple-cursors)。
