[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# im-select.nvim：Windows 输入法切换（仅 windows）

仓库：`keaising/im-select.nvim`。Windows 分支启动时 setup，调用 `im-select.exe`，把普通模式
默认输入法设为 `1033`（美式英语），再在插入模式恢复之前的输入法。

首次运行 `im-select.exe` 查看当前 IME 标识，用 `Get-Command im-select.exe` 检查 PATH；你的
英文输入法 ID 不同就修改 `default_im_select`。若每次切换都闪烁或无法恢复，先在普通
PowerShell 中验证 executable，再执行 `:checkhealth`。main 不安装此插件。

Windows 实机已确认 `im-select.exe` 可读取当前输入法、切换到 `1033`，并恢复原输入法。不同
机器的 IME ID 可能不同，先手工执行 `im-select.exe` 核对。上游：
[im-select.nvim](https://github.com/keaising/im-select.nvim)。
