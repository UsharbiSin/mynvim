[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# gitsigns.nvim：行级 Git 状态

仓库：`lewis6991/gitsigns.nvim`，配置见 [gitsigns.lua](../../../lua/config/gitsigns.lua)。它在
sign column 显示新增、修改、删除，并启用当前行 blame。

按键只在 Gitsigns 成功 attach 的 Git 文件 buffer 中存在：`<Space>ph` 预览 hunk，
`<Space>[h` / `<Space>]h` 跳前后 hunk，`<Space>td` 显示/隐藏删除行，`<Space>rh` 重置
当前 hunk。最后一项会直接丢弃该块未提交修改，操作前先预览或保存补丁。

没有标记时检查文件是否被 Git 跟踪，并运行 `:Gitsigns debug_messages` 和 `:messages`；当前
插件没有专用 health provider。
上游：[gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)。
