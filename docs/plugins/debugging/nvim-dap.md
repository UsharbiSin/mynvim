[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nvim-dap：调试协议核心

仓库：`mfussenegger/nvim-dap`。打开 Python、C、C++、CUDA 文件才加载，配置见
[debugging.lua](../../../lua/config/debugging.lua)。它是 DAP 客户端，不包含 gdb、debugpy、
codelldb 或 cppdbg；adapter 可执行文件必须另外安装。

## 当前 adapter 与配置

| 名称 | 命令 | 用途/限制 |
| --- | --- | --- |
| `codelldb` | `codelldb` | 可选 C/C++ launch；命令存在时才显示 |
| `cppdbg` | `OpenDebugAD7` | 可选 C/C++/CUDA launch 与 attach；需同时有 gdb |
| `gdb` | `gdb --interpreter=dap ...` | Windows 的 C/C++ 首选；需支持 DAP 的 GDB |
| `cudagdb` | `cuda-gdb` | CUDA launch；需 NVIDIA 工具链 |
| `python` | `python -m debugpy.adapter` | 两个系统均从 Mason debugpy 目录解析，并选择对应的 `bin` 或 `Scripts` 路径 |

Windows 的 `c` 与 `cpp` 共用本机可用配置，优先原生 GDB DAP，并只加入命令实际存在的
codelldb/cppdbg 选项。实机已用 GDB 16.2 调试带空格路径的 C 程序，断点成功命中并正常退出。
Arch Linux 与 Windows 均按 PATH 探测原生调试器；Python adapter 按平台使用 Mason debugpy。

## 快捷键

| 按键 | 功能 |
| --- | --- |
| `F1` / `<Space>du` | 切换 DAP UI |
| `F2` / `<Space>ds` | 启动或继续 |
| `F3` / `<Space>di` | 步入 |
| `F4` / `<Space>do` | 步过 |
| `F5` / `<Space>dO` | 步出 |
| `F6` | 重启调试 |
| `F7` / `<Space>dQ` | 终止 |
| `<Space>dq` | 关闭会话 |
| `<Space>dr` | restart frame |
| `<Space>dc` | 运行到光标 |
| `<Space>dR` | REPL |
| `<Space>dh` | 悬浮变量 |
| `<Space>db` / `<Space>dB` | 普通 / 条件断点 |
| `<Space>dD` | 清全部断点 |

典型流程：编译带调试符号的程序，打开源码，设断点，F2，从列表选择 launch 配置，再输入
可执行文件。Python 直接选择 `file` 或带 args 的配置；激活 Conda 时分别解析
`$CONDA_PREFIX/bin/python` 或 Windows `python.exe`。

用 `:lua print(require('dap').status())`、`:DapShowLog`、`:messages` 排错。adapter “启动了”
仍不代表协议兼容，尤其 `codelldb`/`cuda-gdb` 的 executable adapter 需与实际版本验证。
上游：[nvim-dap](https://github.com/mfussenegger/nvim-dap)。
