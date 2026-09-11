[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# im-select.nvim：Windows 输入法切换

仓库：`keaising/im-select.nvim`。仅在 Windows 启动时配置，调用 `im-select.exe`，把普通
模式默认输入法设为 `1033`（美式英语），再在插入模式恢复之前的输入法。

每次启动 Neovim 时，插入模式和终端模式默认使用小狼毫 `2052` 的英文状态。离开插入模式或
终端模式前，配置通过小狼毫命名管道读取 `ascii_mode`；再次进入其中任一模式时恢复该状态。
因此在插入模式通过 Shift 切到中文后，进入终端模式也会恢复中文；切回英文后同样会记住。
状态只在当前 Neovim 会话内保存，下次启动重新默认为英文。小狼毫的
`weasel.custom.yaml` 需要启用 `"global_ascii": true` 并重新部署，当前 Windows 配置已完成。

首次运行 `im-select.exe` 查看当前 IME 标识，用 `Get-Command im-select.exe` 检查 PATH；你的
英文输入法 ID 不同就修改 `default_im_select`。若每次切换都闪烁或无法恢复，先在普通
PowerShell 中验证 executable，再执行 `:checkhealth`。Linux 不安装此插件。

Windows 实机已确认 `im-select.exe` 可读取当前输入法、切换到 `1033`，并恢复原输入法。不同
机器的 IME ID 可能不同，先手工执行 `im-select.exe` 核对。上游：
[im-select.nvim](https://github.com/keaising/im-select.nvim)。

Markdown 表格模式的回车逻辑保持在插入模式内，不会为了移动到行尾发送 `<Esc>`；因此按
回车生成表格行时不会误触 `InsertLeave` 并把中文输入法切回英文。

配置只监听真正离开插入模式的 `InsertLeave`，不监听 `CmdlineLeave`。这是因为
`bullets.vim` 在 Markdown 中通过表达式寄存器生成下一条列表项，按回车时会短暂进入命令行
求值并触发 `CmdlineLeave`，但编辑器仍处于插入流程；忽略该事件可避免输入法被误切到英文。

Markdown 插入模式的 `,f` 会直接定位并删除下一个 `<++>` 占位符，不再通过 `<Esc>`、搜索命令
和 `c4l` 临时退出插入模式，因此不会触发额外的小狼毫状态保存与恢复。
