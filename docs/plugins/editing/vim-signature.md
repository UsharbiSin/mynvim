[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-signature：mark 与 marker 可视化

仓库：`kshenoy/vim-signature`，BufReadPost 加载，在 sign column 显示 Vim marks 和自定义
markers。配置意图见 [tools.lua](../../../lua/config/tools.lua)：`m.` 切换当前行 mark，
`m,` 放置下一个 mark，`mn`/`mp` 跳前后 spot，`dm-` 清当前行，`dm/` 清 marks。

但上游在 plugin 文件被 source 时就建立默认映射，而本项目到 lazy 的 config 阶段才设置
`SignatureMap`，这些自定义值可能太晚，实际仍是上游默认。请运行
`:verbose nmap m.`、`:verbose nmap mn` 确认本机行为。`:SignatureToggleSigns` 可切换显示；
不要把 Vim mark 与 Git hunk 混淆。

上游：[vim-signature](https://github.com/kshenoy/vim-signature)。
