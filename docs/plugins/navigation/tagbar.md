[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# tagbar：代码符号大纲

仓库：`preservim/tagbar`。按 `T` 执行 `:TagbarOpenAutoClose` 时加载，展示当前文件的类、函数、
变量等 tags。

Tagbar 依赖外部 Exuberant/Universal Ctags；Arch 推荐安装 `universal-ctags`，Windows 需把
`ctags.exe` 加入 PATH。检查 `:echo executable('ctags')` 和 `:TagbarDebug`。它基于 tags，
与 LSP documentSymbol 不同；语言不被 ctags 支持时即使 LSP 正常也可能为空。

上游：[tagbar](https://github.com/preservim/tagbar)。
