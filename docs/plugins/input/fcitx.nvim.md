[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# fcitx.nvim：Linux 输入法切换（main 条件加载）

仓库：`h-hg/fcitx.nvim`。main 仅在 Linux 加载，目标是在离开插入模式时切回英文，返回插入模式时
恢复输入法，避免普通模式命令被中文输入法吞掉。本项目未传入自定义选项。

它要求正在运行 Fcitx/Fcitx5 及相应控制命令。检查 `fcitx5-remote` 或 `fcitx-remote` 是否在
PATH、图形会话环境变量是否被终端继承。SSH/headless 下可能无输入法服务。main 在 Windows
跳过此插件并改用 im-select。

上游：[fcitx.nvim](https://github.com/h-hg/fcitx.nvim)。
