[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# goyo.vim：专注写作模式

仓库：`junegunn/goyo.vim`。输入 `:Goyo` 时才加载；本项目还计划用 `<Space>gy` 切换，
该映射写在 [ui.lua](../../../lua/config/ui.lua) 中。

由于 `ui.lua` 随 Airline 配置执行，正常完整启动后映射应存在。Goyo 会临时调整窗口布局、
宽度和界面元素，再次 `:Goyo` 恢复；它不会改变 Markdown 文件内容。若 `<Space>gy`
不存在，先执行 `:Goyo` 并检查 `:verbose nmap <leader>gy`。与 Airline/侧栏恢复冲突时，
先关闭 Goyo 再重新打开文件树。

上游：[goyo.vim](https://github.com/junegunn/goyo.vim)。
