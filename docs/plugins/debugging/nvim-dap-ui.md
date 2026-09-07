[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nvim-dap-ui：调试界面

仓库：`rcarriga/nvim-dap-ui`，作为 nvim-dap 依赖加载，依赖
[nvim-nio](../dependencies/nvim-nio.md)。配置在 [debugging.lua](../../../lua/config/debugging.lua)。

启动/附加前自动打开，terminated/exited 前自动关闭。左侧占总宽约 20%，显示 stacks、scopes、
breakpoints、watches；底部占总高约 20%，显示 REPL 与 console。F1 或 `<Space>du` 手动切换。
配置还尝试调整名为 `OverseerList` 的窗口，但本项目没有声明 Overseer，通常不会产生效果。

面板空白通常意味着程序尚未暂停；先确认 adapter 和断点。DAP 当前没有专用 health
provider，可用 `:lua print(require('dap').status())`、`:DapShowLog` 和 `:messages` 排错；UI
异常再检查 nvim-nio。上游：[nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui)。
