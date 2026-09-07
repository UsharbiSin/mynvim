# Windows 11（windows 分支）安装与配置

[返回项目使用说明](../../README.md) · [插件索引](../README.md) · [分支差异](../branch-differences.md)

本文面向 Windows 11 原生 Neovim，不是 WSL。2026-09-07 已在 Windows 11、Neovim 0.12.4、
PowerShell 5.1 和 WezTerm 环境完成实机验证。数据库网络、未安装的可选语言运行时和所有终端
图像协议仍需在使用机器验证。若项目实际在 WSL 内开发，通常应在 WSL 内安装 Neovim 并使用
`main` 分支，避免混用 Windows 路径与 Linux 工具链。

## 1. 安装基础软件

打开 PowerShell，先确认 winget 可用：

```powershell
winget --version
winget search Neovim
winget search Git.Git
winget search OpenJS.NodeJS.LTS
```

常用安装命令如下；企业环境或 winget 源显示不同 ID 时，以 `winget search` 的结果为准：

```powershell
winget install --id Neovim.Neovim -e
winget install --id Git.Git -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id Python.Python.3.13 -e
winget install --id 7zip.7zip -e
winget install --id ImageMagick.ImageMagick -e
```

关闭并重新打开 PowerShell，再确认：

```powershell
nvim --version
git --version
node --version
npm --version
python --version
magick --version
tar --version
curl.exe --version
```

若 PowerShell profile 把 `nvim` 定义成启动 GUI 的函数，普通 `nvim --headless` 并不会执行
无界面检查。先运行 `Get-Command nvim -All` 和 `where.exe nvim`，测试时直接调用返回的
`nvim.exe` 路径。

本仓库锁定的 nvim-treesitter 还要求 Tree-sitter CLI >= 0.26.1 和 C 编译器。可安装 Rust
后用 Cargo 安装 CLI：

```powershell
winget install --id Rustlang.Rustup -e
rustup default stable
cargo install tree-sitter-cli
tree-sitter --version
```

也可使用 Tree-sitter 官方发布的 Windows 二进制，但必须把所在目录加入用户 PATH。C/C++
请选择一套原生工具链并保持一致：Visual Studio Build Tools（MSVC）或 LLVM/MinGW。配置的
F10 使用 `gcc`/`g++`，C/C++ 调试优先使用支持 DAP 的 `gdb`。`codelldb`、
`OpenDebugAD7` 和 `cuda-gdb` 是可选适配器，只有命令存在时才显示对应启动项。

安装任一 Nerd Font，在 Windows Terminal 的配置中将当前 profile 字体设为它；仅下载字体
文件而不选择字体，图标仍会显示成方块。

## 2. 备份旧数据

退出所有 Neovim 实例。在 PowerShell 中备份配置：

```powershell
$stamp = Get-Date -Format yyyyMMdd-HHmmss
if (Test-Path $env:LOCALAPPDATA\nvim) {
  Rename-Item $env:LOCALAPPDATA\nvim ("nvim.bak-" + $stamp)
}
```

如果要完全隔离旧插件和缓存，再备份这些目录：

```powershell
if (Test-Path $env:LOCALAPPDATA\nvim-data) {
  Rename-Item $env:LOCALAPPDATA\nvim-data ("nvim-data.bak-" + $stamp)
}
```

不要直接删除备份。确认新配置稳定后再自行清理。

## 3. 克隆 windows 分支

```powershell
git clone --branch windows https://github.com/UsharbiSin/mynvim.git $env:LOCALAPPDATA\nvim
nvim
```

首次启动会下载 lazy.nvim 和插件，markdown-preview.nvim 的构建步骤会执行 npm install。
等待完成后运行：

```vim
:Lazy sync
:Lazy log
:Mason
:checkhealth
```

如果 Git 能在 PowerShell 中运行、Neovim 中却找不到，说明启动 Neovim 的 GUI/终端继承了
旧 PATH；完全退出 Windows Terminal 或注销后重试。

## 4. Mason、LSP 和格式化器

Mason 配置会请求六个 LSP：pylsp、html、jsonls、sqls、lua_ls、clangd。等待 `:Mason`
显示安装完成，再安装其余程序：

```vim
:MasonInstall black isort prettier stylua sqlfluff debugpy
```

SQLS 的安装可能需要 Go：

```powershell
winget search GoLang.Go
winget install --id GoLang.Go -e
go version
```

每打开一种语言都用以下命令确认真实状态：

```vim
:checkhealth vim.lsp
:lua vim.print(vim.lsp.get_clients({bufnr=0}))
:lua print(vim.fn.exepath('clangd'))
:ConformInfo
```

## 5. 必须核对的个人路径

### Markdown 浏览器

`lua/config/markdown.lua` 将 `vim.g.mkdp_browser` 留空，由系统默认浏览器处理预览 URL；HTML
的 F10 也通过 `vim.ui.open()` 调用系统关联。用 F8 启动 Markdown 预览、F9 停止。若要固定
浏览器，再把 `vim.g.mkdp_browser` 设置为本机可执行文件路径。

### 输入法

windows 使用 im-select.nvim，配置假设 `im-select.exe` 已在 PATH，英文输入法代码是 `1033`。
先在 PowerShell 运行：

```powershell
im-select.exe
Get-Command im-select.exe
```

若程序不存在，从 [im-select.nvim 文档](../plugins/input/im-select.nvim.md)所指上游安装，并把
真实英文 IME ID 写入 `default_im_select`。

### Vimwiki 和个人文件

- Vimwiki 默认 `~/vimwiki/`；在 Neovim 中用 `:echo expand('~/vimwiki')` 查看解析结果。
- `<Space>pw` 打开 `$USERPROFILE/Documents/pswd.md`。不用此个人映射就删除。
- SQL 数据库信息读取 `DB_USER_*` 等环境变量；只有同一连接的五项变量完整时才把该连接传给
  SQLS，未配置数据库不会阻止 SQLS 启动。可在启动 Neovim 前临时设置：

```powershell
$env:DB_USER_TY = 'user'
$env:DB_PASSWORD_TY = 'replace-me'
$env:DB_HOST_TY = '127.0.0.1'
$env:DB_PORT_TY = '3306'
$env:DB_NAME_TY = 'database'
nvim query.sql
```

需要永久变量时可使用 Windows 用户环境变量界面。不要把密码提交到 Lua 或 PowerShell profile。

## 6. 调试器逐项配置

Python adapter 已指向 Mason debugpy 的：

```text
%LOCALAPPDATA%\nvim-data\mason\packages\debugpy\venv\Scripts\python.exe
```

执行 `:MasonInstall debugpy` 后用以下命令确认：

```vim
:lua print(vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/Scripts/python.exe')
```

C 和 C++ 共用本机可用的启动配置。若 `gdb` 在 PATH，首项是 `Launch (gdb DAP)`；安装
`codelldb` 或 `OpenDebugAD7` 后会自动增加对应选项。当前实机的 GDB 16.2 已完成真实协议
会话测试：含空格路径的 C 程序可加载，断点可验证并命中，会话以退出码 0 结束。可用以下
命令先确认适配器本身：

```powershell
gdb --version
gdb --interpreter=dap --batch -ex quit
```

CUDA 启动项同样只在 `cuda-gdb` 或 cppdbg 依赖齐全时显示。

## 7. F10 一键运行

Windows 分支由 `lua/core/runner.lua` 生成参数数组，不通过 PowerShell 拼接文件名。当前实机
已在含空格临时目录完成 C 编译和执行测试。Python 自动优先选择 Windows 的 `python`，HTML
使用系统关联，Markdown/Vimwiki 使用 `MarkdownPreview`，JavaScript 运行当前文件。

每种语言仍需安装对应编译器或运行时。TeX 分支需要当前未声明的 Vimtex，Dart 分支需要当前
未启用的 Coc；缺少程序或命令时会显示错误，不会静默执行失败。

## 8. 图片与剪贴板

img-clip 会调用 `magick convert`，保存 AVIF 到当前 Markdown 文件旁的 `.markdown_images/`。
确认 `magick` 在 Neovim 内可见：

```vim
:echo executable('magick')
:checkhealth snacks
```

img-clip.nvim 当前没有专用 health provider。用 `<Space>pi` 后检查 `.markdown_images/` 是否
生成 AVIF 文件；也可用 `:messages` 查看转换错误。实机 ImageMagick 已确认支持 AVIF 读写。

Snacks 行内图片还取决于 Windows Terminal/终端模拟器是否支持相应图像协议。图片粘贴成功
但行内不显示时，先看文件是否真正生成，再分别排查 ImageMagick 与终端显示能力。

## 9. 完整验收清单

1. `nvim --version` 至少 0.11，`tree-sitter --version` 至少 0.26.1。
2. `:Lazy` 无 failed，`:Mason` 六个 LSP 已安装。
3. 检查 `:checkhealth`、`:checkhealth nvim-treesitter`、`:checkhealth snacks`；无界面模式会因
   `TERM=dumb` 报图像协议错误，未启用的 lazygit/picker 项也可忽略。
4. 打开 Lua/Python/C++/Markdown/SQL 文件检查 filetype、LSP 和高亮。
5. `tt`、`L`、`T` 可打开文件树、撤销树、Tagbar（Tagbar 还需 ctags）。
6. F8/F9 能启动/停止 Markdown 预览。
7. `<Space>pi` 能生成 AVIF 文件并插入链接。
8. Python debugpy 路径存在；C/C++ 的 GDB DAP 能命中断点。
9. 输入中文后按 Esc 返回 Normal，确认输入法切回英文。
10. `:checkhealth codex` 无错误，`<Space>ac` 能打开当前项目的 Codex 终端。

windows 分支已经包含 Codex 集成，但仍未安装 main 的 boole.nvim。具体差异见
[分支差异](../branch-differences.md)。

仓库提供可重复的 Windows 专项检查。PowerShell 中先解析真实应用路径，再执行：

```powershell
$nvimExe = (Get-Command nvim.exe).Source
& $nvimExe --headless -u init.lua -l tests/windows.lua
```

当前结果为 16 项通过，覆盖平台识别、带空格路径的一键运行、SQLS 空连接启动与命令注册、
GDB 配置、默认浏览器与 Vimwiki 图表集成。若机器缺少 gcc、gdb 或六个 Mason LSP，测试会
明确失败。
