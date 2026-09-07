[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nvim-dap：调试协议核心

仓库：`mfussenegger/nvim-dap`。打开 Python、C、C++、CUDA 文件才加载，配置见
[debugging.lua](../../../lua/config/debugging.lua)。它是 DAP 客户端，不包含 gdb、debugpy、
codelldb 或 cppdbg；adapter 可执行文件必须另外安装。

## 当前 adapter 与配置

| 名称 | 命令 | 用途/限制 |
| --- | --- | --- |
| `codelldb` | `codelldb` | C++ launch；必须在 PATH |
| `cppdbg` | `OpenDebugAD7` | C++/CUDA launch 与 attach；需单独安装 |
| `gdb` | `gdb --interpreter=dap ...` | 声明了 adapter，但已有 C++ 配置实际用 cppdbg |
| `cudagdb` | `cuda-gdb` | CUDA launch；需 NVIDIA 工具链 |
| `python` | `python -m debugpy.adapter` | main 是作者绝对路径；windows 是 Mason debugpy |

只给 `cpp`、`cuda`、`python`、`qmt` 定义 launch 配置；`c` 虽触发加载，却没有
`dap.configurations.c`。C++ 的 cppdbg 条目 main 与 windows 都有 `/usr/bin/gdb` 遗留（CUDA
的相似条目在 windows 改成 `gdb.exe`）。详细平台调整见 Arch/Windows 指南。

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
