[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# tagbar：代码符号大纲

仓库：`preservim/tagbar`。按 `T` 执行 `:TagbarOpenAutoClose` 时加载，展示当前文件的类、函数、
变量等 tags。

Tagbar 依赖外部 Universal Ctags。配置不写死安装目录，只从 Neovim 继承的 `PATH` 查找
`ctags`；安装或修改 PATH 后需要重启 Neovim。可用 `:echo exepath('ctags')` 检查实际路径，
用 `:TagbarDebug` 排查语言支持。Tagbar 基于 tags，与 LSP documentSymbol 不同；语言不被
ctags 支持时，即使 LSP 正常也可能为空。

## Linux

Arch Linux 安装：`sudo pacman -S --needed universal-ctags`。其他发行版使用自己的包管理器
安装 Universal Ctags，并确认终端执行 `ctags --version` 正常。

## Windows

执行 `winget install UniversalCtags.Ctags` 安装，然后重新打开终端和 Neovim，确认
`where.exe ctags` 与 `:echo exepath('ctags')` 都能找到程序。按 `T` 时仍未找到会显示中文提示。

上游：[tagbar](https://github.com/preservim/tagbar)。
