[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-FIGlet：ASCII 艺术字

仓库：`fadein/vim-FIGlet`，`:FIGlet` 时加载。上游插件调用外部 `figlet` 生成艺术字；Arch 可
安装 `figlet`，Windows 需自行提供对应可执行文件并加入 PATH。

本项目另有普通模式 `tx`，实际执行 `:r !figlet ` 并等待你在命令行补充文字，它不一定触发
插件加载，直接依赖 shell 的 `figlet`。检查 `:echo executable('figlet')`。生成结果会插入
buffer，可用 `u` 撤销。

上游：[vim-FIGlet](https://github.com/fadein/vim-FIGlet)。
