[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-airline：状态栏

仓库：`vim-airline/vim-airline`。它在底部显示模式、文件、Git、编码和文件类型；两个系统都
在启动阶段加载，并通过 [ui.lua](../../../lua/config/ui.lua) 完成配置。

本项目启用 hunks 扩展，并把 X 区设置成“当前 Conda 环境 + filetype”。只有启动 Neovim
前存在 `CONDA_DEFAULT_ENV` 时才显示蛇形标记。`laststatus=2` 保证状态栏常驻；主题由
[vim-airline-themes](vim-airline-themes.md)提供。全局 `R` 会 source 配置并执行
`AirlineRefresh`。

图标乱码时先配置 Nerd Font；Git 段为空时确认当前文件在仓库中并查看 Gitsigns/Fugitive。
Airline 并不创建 Conda 环境，也不激活它。上游：[vim-airline](https://github.com/vim-airline/vim-airline)。
