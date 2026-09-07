[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# undotree：撤销历史树

仓库：`mbbill/undotree`。按 `L` 或执行 `:UndotreeToggle` 才加载；配置见
[undotree.lua](../../../lua/config/undotree.lua)。本项目关闭自动 Diff 窗口，让界面只显示历史树。

撤销树展示的是 Vim 的分叉撤销历史，可选择旧状态后继续编辑，而不只是线性 `u`/Ctrl-r。
持久化能力取决于 `undofile`，当前核心选项没有启用它，所以退出 Neovim 后不要假定历史仍在。
若 `L` 无响应，用 `:verbose nmap L` 检查冲突并直接执行命令。

上游：[undotree](https://github.com/mbbill/undotree)。
