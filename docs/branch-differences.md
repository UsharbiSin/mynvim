# main 与 windows 分支差异

[返回项目使用说明](../README.md) · [插件索引](README.md)

本页按 2026-09-08 的两个分支配置比较。两个分支共享主体插件和大多数快捷键，但不能
视为仅换了一条路径。

| 方面 | main（Arch Linux） | windows（Windows 11） |
| --- | --- | --- |
| 输入法 | `h-hg/fcitx.nvim` | 按运行平台选择：Windows 使用 `keaising/im-select.nvim`（默认 IME 代码 `1033`），Linux 使用 `h-hg/fcitx.nvim` |
| 布尔值切换 | `boole.nvim`，`Ctrl-a`/`Ctrl-x` | `boole.nvim`，`Ctrl-a`/`Ctrl-x` |
| Codex | Snacks terminal、命令、health、测试和文档均存在 | 已完整接入，并兼容原生程序与 npm 启动脚本 |
| Snacks | 启动即加载，图片、公式、通知、终端 | 启动即加载，图片、公式、通知、终端 |
| SQL 数据库 | SQLS、SQL Runner、Dadbod Grip；Linux 待实机验证 | SQLS、SQL Runner、Dadbod Grip；Windows 已实测 |
| 文档图表 | diagram.nvim + image.nvim；Linux 待实机验证 | diagram.nvim + image.nvim；Windows 已实测 |
| Markdown 浏览器 | `/usr/lib/firefox/firefox` | 系统默认浏览器 |
| Markdown CSS | 作者 Linux 绝对路径 | `stdpath('config')/markdown.css` |
| Vimwiki 图片 | 作者 Linux 绝对路径 | `~/vimwiki/.markdown_images` |
| 快速打开配置 | `~/.config/nvim/init.lua` | `stdpath('config')/init.lua` |
| 密码文档 | `~/Documents/pswd.md` | 使用 Neovim 展开的用户目录，即 `~/Documents/pswd.md` |
| Python DAP adapter | 作者 virtualenv 绝对路径 | Mason 的 `debugpy/venv/Scripts/python.exe` |
| Conda Python | `$CONDA_PREFIX/bin/python` | 按运行平台选择 `$CONDA_PREFIX/bin/python` 或 `$CONDA_PREFIX/python.exe` |
| C/C++ 调试 | codelldb/cppdbg，含 `/usr/bin/gdb` | 优先原生 GDB DAP，并按已安装程序生成菜单 |
| CUDA 调试 | cuda-gdb/cppdbg | 仅在对应程序已安装时显示 |
| LSP 诊断 | 行尾 virtual text 关闭 | 行尾 virtual text 开启 |
| Semantic tokens | 依赖新版默认行为 | 附着时调用 0.12 的 `enable()` 接口 |
| 默认折叠 | manual，起始层 99 | indent，层 99 |

## F10 一键运行

windows 分支已把 F10 拆到 `lua/core/runner.lua`，编译和运行参数不再经过 shell 拼接，并已
实测带空格路径。该模块也能在 Linux 上运行，并通过运行时平台检测选择可执行文件名和 Python 命令。它会：

- 为 Windows C/C++ 输出 `.exe`，编译成功后再启动；
- Windows 优先使用 `python`，JavaScript 直接运行当前文件；
- HTML 交给 `vim.ui.open()`，Markdown/Vimwiki 调用 `MarkdownPreview`；
- 找不到外部程序或命令时显示明确错误。

TeX 仍依赖当前未声明的 Vimtex，Dart 仍依赖当前未启用的 Coc。main 分支保留原有 shell
实现，跨分支同步这部分时应保留平台差异。详见 [Windows 11 指南](platforms/windows11.md)。

## 插件锁差异

两分支绝大多数锁定插件提交相同。windows 分支声明两种输入法插件，再按运行平台只加载其中一种；
锁文件仍只保留该分支已验证的 Windows 插件版本，Linux 首次安装会在本地补充 fcitx 的锁定记录。
lazy.nvim 自身的锁定提交也可能不同。不要把一个分支的 `lazy-lock.json` 单独复制到另一个分支，否则会让代码
与锁文件失配。

合并 main 到 windows 时，需要人工处理 `plugin-list.lua`、`snacks.lua`、`debugging.lua`、
`markdown.lua`、`keymaps.lua` 和 `options.lua`。两个分支当前都已完整接入 Codex，后续同步时
仍应将模块、health、测试、快捷键和 Snacks terminal 配置作为一个整体维护。
