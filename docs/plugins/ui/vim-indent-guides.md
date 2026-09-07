[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-indent-guides：缩进引导线

仓库：`preservim/vim-indent-guides`。读取文件前加载。配置意图位于
[ui.lua](../../../lua/config/ui.lua)：启动即启用、从第 2 层开始、宽度 1、颜色变化 1%。

需要注意，`ui.lua` 是由 vim-airline 的 config 调用，而该调用时机与 BufReadPre 插件加载
可能不同；若引导线状态不符，用 `:IndentGuidesToggle` 手动切换，并用
`:verbose let g:indent_guides_enable_on_vim_startup` 检查值。项目还取消默认 `<Leader>ig`
映射，没有自定义替代按键。它只显示缩进，不改变 `shiftwidth`。

上游：[vim-indent-guides](https://github.com/preservim/vim-indent-guides)。
