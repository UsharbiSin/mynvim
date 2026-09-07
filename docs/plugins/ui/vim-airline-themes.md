[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-airline-themes：状态栏主题

仓库：`vim-airline/vim-airline-themes`。它作为 vim-airline 的依赖安装，提供状态栏配色集合，
自身不负责状态栏逻辑。

本项目没有设置 `g:airline_theme`，因此使用 Airline 根据当前 colorscheme 得到的默认样式。
若要固定主题，可在 Airline 加载前设置 `vim.g.airline_theme = "主题名"`，然后执行
`:AirlineRefresh`；可用 `:help airline-themes` 查锁定版本的名称。主题显示异常通常来自
终端 true color、Nerd Font 或自定义 highlight，而不是此依赖未安装。

上游：[vim-airline-themes](https://github.com/vim-airline/vim-airline-themes)。
