[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nvim-dap-python：Python DAP 辅助层

仓库：`mfussenegger/nvim-dap-python`，作为 nvim-dap 依赖安装。上游可生成 debugpy adapter、
测试方法/类等配置，但当前 [debugging.lua](../../../lua/config/debugging.lua)没有调用
`require('dap-python').setup(...)`，而是手写 `dap.adapters.python` 与两条 launch 配置。

所以“插件已安装”不表示 `:DapPythonTestMethod` 等辅助命令可用。当前可用工作流以
[nvim-dap](nvim-dap.md)中的 F2 和 Python launch 列表为准。若以后启用 dap-python，应避免
与手写同名 adapter 重复覆盖，并传入真正的 debugpy Python 路径。

上游：[nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python)。
