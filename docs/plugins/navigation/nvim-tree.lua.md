[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nvim-tree.lua：文件树

仓库：`nvim-tree/nvim-tree.lua`。按 `tt` 或 `<Space>f` 时加载；依赖
[nvim-web-devicons](nvim-web-devicons.md)。配置在 [nvim-tree.lua](../../../lua/config/nvim-tree.lua)，
同时禁用 netrw。

全局 `tt` 以当前 Git 仓库根目录打开文件树，再按一次关闭。同一仓库内切换子目录时根节点
保持不变；切换到其他仓库后使用新仓库根目录。仓库外使用当前文件所在目录，无名或特殊
buffer 使用当前工作目录。
`<Space>f` 在文件树中定位当前文件。树内常用键：Enter 打开/展开，`i` 垂直分屏，
`o` 标签页，`h` 收起，`/` 搜索，`n`/`N` 跳到下一个/上一个匹配，Backspace 上级根，
`a`/`M` 新建，`rn` 重命名，`dD` 永久删除，
`yy`/`dd`/`pp` 复制剪切粘贴，`yp`/`yn` 复制路径/文件名，`.` 或 `zh` 隐藏文件，`R`
刷新，`?` 帮助，`q` 关闭。`s` 标记节点，`[c ]c` 跳 Git 状态，`[d ]d` 跳诊断。

默认隐藏点文件和 `.git`，宽度 30，显示 Git 与诊断。`dD` 是永久文件操作，确认目标后再用。
上游：[nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua)。
