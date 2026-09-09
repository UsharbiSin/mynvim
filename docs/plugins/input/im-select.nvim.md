[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# im-select.nvim：Windows 输入法切换（main 条件加载）

仓库：`keaising/im-select.nvim`。main 仅在 Windows 启动时配置，调用 `im-select.exe`，把普通
模式默认输入法设为 `1033`（美式英语），再在插入模式恢复之前的输入法。

首次运行 `im-select.exe` 查看当前 IME 标识，用 `Get-Command im-select.exe` 检查 PATH；你的
英文输入法 ID 不同就修改 `default_im_select`。若每次切换都闪烁或无法恢复，先在普通
PowerShell 中验证 executable，再执行 `:checkhealth`。main 不安装此插件。

Windows 实机已确认 `im-select.exe` 可读取当前输入法、切换到 `1033`，并恢复原输入法。不同
机器的 IME ID 可能不同，先手工执行 `im-select.exe` 核对。上游：
[im-select.nvim](https://github.com/keaising/im-select.nvim)。

Markdown 表格模式的回车逻辑保持在插入模式内，不会为了移动到行尾发送 `<Esc>`；因此按
回车生成表格行时不会误触 `InsertLeave` 并把中文输入法切回英文。

配置只监听真正离开插入模式的 `InsertLeave`，不监听 `CmdlineLeave`。这是因为
`bullets.vim` 在 Markdown 中通过表达式寄存器生成下一条列表项，按回车时会短暂进入命令行
求值并触发 `CmdlineLeave`，但编辑器仍处于插入流程；忽略该事件可避免输入法被误切到英文。

Markdown 插入模式的 `,f` 会直接定位并删除下一个 `<++>` 占位符，不再通过 `<Esc>`、搜索命令
和 `c4l` 临时退出插入模式，因此不会重置微软中文输入法中由 Shift 控制的中英文状态。
