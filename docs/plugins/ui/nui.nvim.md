[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# nui.nvim：UI 组件依赖

仓库：`MunifTanjim/nui.nvim`。它作为 Noice 依赖安装，提供 popup、layout、menu、input 等
Lua 组件。本项目不直接调用其 API，也没有单独快捷键或命令。

删除它会导致 Noice require 失败；Noice 的健康检查同时验证该依赖。它不是完整的用户界面，
正常情况下无需单独配置。版本由 `lazy-lock.json` 锁定。

上游：[nui.nvim](https://github.com/MunifTanjim/nui.nvim)。
