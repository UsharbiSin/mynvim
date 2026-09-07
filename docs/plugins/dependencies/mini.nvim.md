[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# mini.nvim：render-markdown 图标依赖

仓库：`nvim-mini/mini.nvim`，作为 render-markdown.nvim 的依赖安装。Mini 是一组独立模块，
但本项目没有 setup 任一完整 mini 功能，只让 render-markdown 使用其图标能力。

因此不要期待 mini.files、mini.pick、mini.surround 等命令或映射。需要这些功能必须分别
setup；当前文件树和 surround 已由其他插件承担。版本由 `lazy-lock.json` 锁定。

上游：[mini.nvim](https://github.com/nvim-mini/mini.nvim)。
