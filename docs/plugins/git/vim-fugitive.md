[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-fugitive：Git 命令集成

仓库：`tpope/vim-fugitive`。main 在两个系统都直接加载，未做额外配置。它把 Git 状态、diff、blame、
提交和对象浏览带入 Neovim；最常用入口是 `:Git` 或 `:Git status`。

典型流程：`:Git` 打开状态页，在文件行用 `s` 暂存/取消暂存，用 `=` 展开 diff，完成后
`:Git commit`。具体状态页按键以 `g?` 和 `:help fugitive` 为准。所有命令作用于当前 Git
仓库；本项目启用 `autochdir`，执行前用 `:pwd` / `:Git rev-parse --show-toplevel` 确认根目录。

外部 `git` 必须在 PATH。上游：[vim-fugitive](https://github.com/tpope/vim-fugitive)。
