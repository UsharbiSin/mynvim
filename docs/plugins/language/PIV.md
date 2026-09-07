[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# PIV：PHP 集成增强

仓库：`spf13/PIV`，仅 PHP 文件加载。PIV（PHP Integration for Vim）提供 PHP 语法、文档
查询、补全/跳转相关辅助，实际功能依赖 Vim/Neovim 能力和外部工具。

本项目没有 PHP LSP、PHP formatter 或 PIV 专用配置，也没有保证 `php` 可执行文件存在；
因此这里应理解为基础 PHP 编辑增强，而不是完整 PHP IDE。打开 `.php` 后查看
`:help PIV`、`:scriptnames` 和 `:echo executable('php')`。

上游：[PIV](https://github.com/spf13/PIV)。
