[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nvim-dap-virtual-text：行内调试值

仓库：`theHamsta/nvim-dap-virtual-text`，随 DAP 加载并在配置中调用默认 `setup()`。调试器暂停
时，它在相关源码行旁显示变量值和变化，依赖 nvim-dap；Tree-sitter 有助于定位变量定义。

本项目没有定制前缀、变化高亮或只显示当前 frame。显示内容来自 adapter，优化构建、无调试
符号或 adapter 不提供变量时可能为空。与 LSP 诊断 virtual text 重叠时，可临时执行
`:DapVirtualTextToggle`，或在 setup 中调整显示策略。

上游：[nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text)。
