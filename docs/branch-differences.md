# Arch Linux 与 Windows 设置差异

[返回项目使用说明](../README.md) · [插件索引](README.md)

`main` 使用同一套配置支持 Arch Linux 和 Windows 11。`init.lua` 在启动时设置
`vim.g.is_win`，只有确实依赖操作系统的部分才进行条件选择。

两个系统当前均使用 Neovim 0.12.5，共用 Neovim 0.11+ 原生 LSP、Tree-sitter 新接口和
同一套插件声明。下表描述的是操作系统及外部工具差异，不再代表两个 Git 分支的差异。

| 方面 | Arch Linux | Windows 11 |
| --- | --- | --- |
| 配置目录 | `~/.config/nvim` | `$env:LOCALAPPDATA\nvim` |
| Neovim | 0.12.5 | 0.12.5 |
| 输入法 | `h-hg/fcitx.nvim` | `keaising/im-select.nvim`，英文 IME 代码 `1033` |
| Shell | 继承系统 Shell | 优先 `pwsh`，否则使用 Windows PowerShell |
| Lazy rocks | 使用 Lazy 默认设置 | 禁用 luarocks/hererocks，避免 Windows 安装失败 |
| Tree-sitter 编译器 | 使用 Tree-sitter 自动选择的编译器 | 指定 `gcc` |
| Vimwiki 目录 | `~/vimwiki/` | `E:/@home/usharbisin/vimwiki/` |
| Markdown 浏览器 | 系统默认浏览器 | 系统默认浏览器 |
| Markdown CSS | `stdpath('config')/markdown.css` | `stdpath('config')/markdown.css` |
| 密码文档 | `~/Documents/pswd.md` | `%USERPROFILE%/Documents/pswd.md` |
| Python 命令 | F10 优先 `python3` | F10 优先 `python` |
| 编译产物 | C/C++ 可执行文件无扩展名 | C/C++ 可执行文件使用 `.exe` |
| debugpy | Mason 环境的 `bin/python` | Mason 环境的 `Scripts/python.exe` |
| Conda Python | `$CONDA_PREFIX/bin/python` | `$CONDA_PREFIX/python.exe` |
| C/C++ 与 CUDA 调试 | 按 PATH 中可用的 gdb、codelldb、OpenDebugAD7、cuda-gdb 生成配置 | 同左 |
| LSP 行尾诊断 | 开启 virtual text | 开启 virtual text |
| 代码折叠 | LSP 语法折叠优先，Tree-sitter 回退 | LSP 语法折叠优先，Tree-sitter 回退 |
| WezTerm 配置快捷键 | 不创建 | `<leader>wezt` 打开用户目录下的 WezTerm 配置 |

SQLS、SQL Runner、Dadbod Grip、diagram.nvim、image.nvim、Codex、Markdown 表格和布尔值切换
在两个系统共用同一份配置。SQL 与图表功能已在 Windows 实测；合并后的 Arch Linux 配置仍需
在实机验证外部命令和终端图片协议。

## F10 一键运行

F10 使用 `lua/core/runner.lua`，所有参数以 argv 传递，能处理带空格的路径。它根据系统选择
Python 命令和 C/C++ 输出文件名；HTML 使用 `vim.ui.open()`，Markdown/Vimwiki 调用
`MarkdownPreview`。找不到编译器或解释器时会显示明确错误。

TeX 仍依赖当前未声明的 Vimtex，Dart 仍依赖当前未启用的 Coc。

## 插件锁文件

`lazy-lock.json` 已加入 `.gitignore` 并取消追踪。每个系统由 Lazy 在本地生成和维护自己的锁文件，
因此输入法等条件插件不会再造成跨系统锁文件冲突。
