[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nvim-nio：DAP UI 异步 I/O 依赖

仓库：`nvim-neotest/nvim-nio`，作为 nvim-dap-ui 依赖安装，提供协程、future 和异步 I/O
基础设施。本项目不直接调用，也没有命令和按键。

调试 UI require 失败或健康检查提示 nio 缺失时，在 `:Lazy` 确认它与 nvim-dap-ui 使用锁定
版本安装。普通编辑功能不依赖它；不要为“看不到命令”而判定未生效。

上游：[nvim-nio](https://github.com/nvim-neotest/nvim-nio)。
