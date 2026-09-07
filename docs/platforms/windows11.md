# Windows 11（windows 分支）安装与配置

[返回项目使用说明](../../README.md) · [插件索引](../README.md) · [分支差异](../branch-differences.md)

本文面向 Windows 11 原生 Neovim，不是 WSL。内容基于 `windows` 分支静态审计；当前没有
Windows 实机，因此所有路径、剪贴板、终端图像、编译器和调试器都需要在目标机器验证。
若项目实际在 WSL 内开发，通常应在 WSL 内安装 Neovim 并使用 `main` 分支，避免混用
Windows 路径与 Linux 工具链。

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
F10 使用 `gcc`/`g++`，DAP 又配置 `gdb`、`codelldb`、`OpenDebugAD7`，所以仅装 MSVC 并不能
让所有现有命令自动工作。

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

`lua/config/markdown.lua` 当前写的是：

```text
C:/Program Files/Google/Chrome/Application/chrome-win/chrome.exe
```

这不是 Chrome 最常见的安装路径，而且 `init.lua` 直接拼 shell 字符串，路径中的空格可能
导致 HTML F10 失败。先在 PowerShell 检查自己的路径，例如：

```powershell
Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
Test-Path "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
```

把 `vim.g.mkdp_browser` 改成真实路径后，用 Markdown 的 F8 测试。F8 由插件自己启动浏览器，
比 HTML 的 F10 shell 拼接更可靠。

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
- SQL 数据库信息读取 `DB_USER_*` 等环境变量；可在启动 Neovim 前临时设置：

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

C/C++ 部分仍需人工修复：

- `codelldb` 必须在 PATH，或把 adapter command 改成 Mason/本机绝对路径；
- `OpenDebugAD7` 必须来自可用的 cppdbg 安装；
- `gdb` adapter 需要支持 DAP 的 gdb；
- C++ 的 `Launch (gdb)` 仍写 `/usr/bin/gdb`，必须改成 `gdb.exe` 或真实绝对路径；
- CUDA 的另一条 cppdbg 配置已写 `gdb.exe`，但 CUDA 工具链本身也需安装。

当前只给 `cpp`、`cuda`、`python`、`qmt` 注册了启动配置；插件虽对 `c` filetype 加载，
`dap.configurations.c` 并未定义。每个 adapter 的 wire protocol 也应以实际安装版本验证。

## 7. 修正 F10 一键运行

windows 分支的 F10 尚未完成 Windows 化。推荐在使用前编辑 `init.lua`：

- `python3` 改为本机 `python` 或 `py -3`；
- 去掉 GNU `time`，或改用 PowerShell `Measure-Command`；
- C/C++ 运行 `.\name.exe`，并给文件路径做可靠引用；
- JavaScript 的 `export DEBUG=...` 改为 PowerShell 环境变量语法，或直接运行项目脚本；
- HTML 浏览器路径必须可靠引用；
- Markdown 使用 `MarkdownPreview`/F8，当前 `InstantMarkdownPreview` 不存在；
- 未安装 Vimtex 和 coc.nvim 时，不要依赖 TeX/Dart 分支。

这些修改涉及你的编译器和默认 shell，仓库当前没有一种能覆盖所有 Windows 工具链的通用
写法。修改后在含空格和不含空格的临时目录各测试一次。

## 8. 图片与剪贴板

img-clip 会调用 `magick convert`，保存 AVIF 到当前 Markdown 文件旁的 `.markdown_images/`。
确认 `magick` 在 Neovim 内可见：

```vim
:echo executable('magick')
:checkhealth img-clip
:checkhealth snacks
```

Snacks 行内图片还取决于 Windows Terminal/终端模拟器是否支持相应图像协议。图片粘贴成功
但行内不显示时，先看文件是否真正生成，再分别排查 ImageMagick 与终端显示能力。

## 9. 完整验收清单

1. `nvim --version` 至少 0.11，`tree-sitter --version` 至少 0.26.1。
2. `:Lazy` 无 failed，`:Mason` 六个 LSP 已安装。
3. `:checkhealth`、`:checkhealth nvim-treesitter` 没有阻断项。
4. 打开 Lua/Python/C++/Markdown/SQL 文件检查 filetype、LSP 和高亮。
5. `tt`、`L`、`T` 可打开文件树、撤销树、Tagbar（Tagbar 还需 ctags）。
6. F8/F9 能启动/停止 Markdown 预览。
7. `<Space>pi` 能生成 AVIF 文件并插入链接。
8. Python debugpy 实际启动；C++ adapter 逐一按安装路径测试。
9. 输入中文后按 Esc 返回 Normal，确认输入法切回英文。
10. `:checkhealth codex` 无错误，`<Space>ac` 能打开当前项目的 Codex 终端。

windows 分支已经包含 Codex 集成，但仍未安装 main 的 boole.nvim。具体差异见
[分支差异](../branch-differences.md)。
