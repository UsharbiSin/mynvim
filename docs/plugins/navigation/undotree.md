[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# undotree：撤销历史树

仓库：`mbbill/undotree`。按 `L` 或执行 `:UndotreeToggle` 才加载；配置见
[undotree.lua](../../../lua/config/undotree.lua)。本项目关闭自动 Diff 窗口，让界面只显示历史树。

Undotree 使用外部 `diff` 生成版本差异。配置不会写死 Git 的盘符或安装目录。

## Linux

先确认 `diff --version` 可用；Arch Linux 缺少时执行 `sudo pacman -S --needed diffutils`。

## Windows

Git for Windows 已包含 `diff.exe`，但其工具目录通常不在系统 `PATH` 中。配置会从
`exepath('git')` 返回的实际 Git 路径推导同一安装中的工具目录，并只在找到 `diff.exe`
时加入当前 Neovim 进程的 `PATH`。若 `L` 仍提示找不到 diff，请确认 `where.exe git`
能够找到 Git for Windows；无需写死 `C:`、`D:` 或 `Program Files` 路径。

撤销树展示的是 Vim 的分叉撤销历史，可选择旧状态后继续编辑，而不只是线性 `u`/Ctrl-r。
持久化能力取决于 `undofile`，当前核心选项没有启用它，所以退出 Neovim 后不要假定历史仍在。
若 `L` 无响应，用 `:verbose nmap L` 检查冲突并直接执行命令。

上游：[undotree](https://github.com/mbbill/undotree)。
