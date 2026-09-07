# main 与 windows 分支差异

[返回项目使用说明](../README.md) · [插件索引](README.md)

本页基于 `main` 的 `fd118cb` 与当前 `windows` 配置静态比较。两个分支共享主体插件和
大多数快捷键，但不能视为仅换了一条路径。

| 方面 | main（Arch Linux） | windows（Windows 11） |
| --- | --- | --- |
| 输入法 | `h-hg/fcitx.nvim` | `keaising/im-select.nvim`，默认 IME 代码 `1033` |
| 布尔值切换 | `boole.nvim`，`Ctrl-a`/`Ctrl-x` | 未安装 |
| Codex | Snacks terminal、命令、health、测试和文档均存在 | 已完整接入，并兼容原生程序与 npm 启动脚本 |
| Snacks | 启动即加载，图片、公式、通知、终端 | 启动即加载，图片、公式、通知、终端 |
| Markdown 浏览器 | `/usr/lib/firefox/firefox` | 硬编码 Chrome `C:/Program Files/.../chrome-win/chrome.exe` |
| Markdown CSS | 作者 Linux 绝对路径 | `stdpath('config')/markdown.css` |
| Vimwiki 图片 | 作者 Linux 绝对路径 | `~/vimwiki/.markdown_images` |
| 快速打开配置 | `~/.config/nvim/init.lua` | `stdpath('config')/init.lua` |
| 密码文档 | `~/Documents/pswd.md` | `$USERPROFILE/Documents/pswd.md` |
| Python DAP adapter | 作者 virtualenv 绝对路径 | Mason 的 `debugpy/venv/Scripts/python.exe` |
| Conda Python | `$CONDA_PREFIX/bin/python` | `$CONDA_PREFIX/python.exe` |
| CUDA gdb 条目 | `/usr/bin/gdb` | `gdb.exe` |
| C++ gdb 条目 | `/usr/bin/gdb` | 仍是 `/usr/bin/gdb`，需修复 |
| LSP 诊断 | 行尾 virtual text 关闭 | 行尾 virtual text 开启 |
| Semantic tokens | 依赖新版默认行为 | 附着时显式 start |
| 默认折叠 | manual，起始层 99 | indent，层 99 |

## Windows 尚未迁移的 POSIX 行为

两个分支的 `init.lua` 一键运行主体基本相同，所以 windows 仍包含：

- C/C++ 的 `./程序` 和 GNU `time`；
- Python 的 `python3`；
- Java/sh 的 `time`、`bash`；
- JavaScript 的 `export DEBUG=...`；
- HTML 浏览器命令末尾 `&`，且未可靠引用含空格路径；
- Markdown 的不存在命令 `InstantMarkdownPreview`；
- TeX 的未安装 Vimtex、Dart 的未启用 Coc。

这些不是 Windows 平台文档可以“测试通过”的功能。使用前按
[Windows 11 指南](platforms/windows11.md)修改，或者在 PowerShell/任务系统中单独运行项目命令。

## 插件锁差异

两分支绝大多数锁定插件提交相同。平台输入法插件和 boole 造成条目不同，lazy.nvim 自身
锁定提交也不同。不要把一个分支的 `lazy-lock.json` 单独复制到另一个分支，否则会让代码
与锁文件失配。

合并 main 到 windows 时，需要人工处理 `plugin-list.lua`、`snacks.lua`、`debugging.lua`、
`markdown.lua`、`keymaps.lua` 和 `options.lua`。两个分支当前都已完整接入 Codex，后续同步时
仍应将模块、health、测试、快捷键和 Snacks terminal 配置作为一个整体维护。
