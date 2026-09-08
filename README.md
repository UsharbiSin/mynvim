# mynvim 中文使用说明

这是一套以 Lua 编写、由 `lazy.nvim` 管理的个人 Neovim 配置。`main` 分支同时支持
Arch Linux 和 Windows 11 原生 Neovim，运行时通过 `vim.g.is_win` 选择系统相关设置。
本文既说明已经可用的功能，也标出仍需按机器安装的外部工具和个人路径。

> 当前文档审计日期：2026-09-07。`main` 已在 Arch Linux / Neovim 0.12.5 上完成
> 无界面启动检查；`windows` 已在 Windows 11 / Neovim 0.12.4 上完成原生实机检查。

## 文档入口

| 内容 | 文档 |
| --- | --- |
| Arch Linux 从零安装、升级、验证 | [Arch Linux 配置](docs/platforms/archlinux.md) |
| Windows 11 从零安装、路径适配、验证 | [Windows 11 配置](docs/platforms/windows11.md) |
| Arch Linux 与 Windows 的设置差异 | [系统设置差异](docs/branch-differences.md) |
| 全部插件按功能分类，每个插件单独说明 | [插件文档索引](docs/README.md) |
| 内置 Codex 终端 | [Codex 使用说明](docs/codex.md) |

## 安装 main 分支

| 系统 | 分支 | 配置目录 |
| --- | --- | --- |
| Arch Linux | `main` | `~/.config/nvim` |
| Windows 11 | `main` | `$env:LOCALAPPDATA\nvim` |

同一份配置会按系统选择输入法插件、Shell、调试器路径、Vimwiki 路径和运行命令。

### Arch Linux 快速安装

先阅读[完整的 Arch Linux 步骤](docs/platforms/archlinux.md)。首次安装的最小流程如下：

```bash
sudo pacman -S --needed neovim git curl unzip base-devel tree-sitter-cli nodejs npm imagemagick
mv ~/.config/nvim ~/.config/nvim.bak-$(date +%Y%m%d-%H%M%S)
git clone --branch main https://github.com/UsharbiSin/mynvim.git ~/.config/nvim
nvim
```

首次启动会引导安装 `lazy.nvim` 并下载插件。进入 Neovim 后依次执行：

```vim
:Lazy sync
:Mason
:checkhealth
```

再按需要安装格式化器和 SQL 检查器：

```vim
:MasonInstall black isort prettier stylua sqlfluff debugpy
```

### Windows 11 快速安装

先阅读[完整的 Windows 11 步骤](docs/platforms/windows11.md)。在 PowerShell 中备份旧配置并
克隆 `windows` 分支：

```powershell
if (Test-Path $env:LOCALAPPDATA\nvim) {
  Rename-Item $env:LOCALAPPDATA\nvim ("nvim.bak-" + (Get-Date -Format yyyyMMdd-HHmmss))
}
git clone --branch main https://github.com/UsharbiSin/mynvim.git $env:LOCALAPPDATA\nvim
nvim
```

Windows 需要先安装 Neovim、Git、Node.js、Python、C/C++ 编译器、Tree-sitter CLI、
ImageMagick 和 Nerd Font，并把命令加入 PATH。插件下载完成后执行 `:Lazy sync`、`:Mason`
和 `:checkhealth`。语言编译器、数据库凭据和可选图表渲染器仍按实际用途安装。

## 项目架构

```text
.
├── init.lua                  # 入口、lazy.nvim 引导、F10 一键运行
├── lazy-lock.json            # Lazy 本地生成的插件锁文件，已被 Git 忽略
├── markdown.css              # 浏览器 Markdown 预览样式
├── ftplugin/
│   └── markdown.lua          # Markdown 专用缩写、表格回车逻辑
├── lsp/                      # Neovim 0.11+ 原生 LSP 配置覆盖
│   ├── clangd.lua            # C/C++/CUDA
│   ├── html.lua
│   ├── jsonls.lua
│   ├── lua_ls.lua
│   ├── pylsp.lua
│   └── sqls.lua              # MySQL 连接来自环境变量
├── lua/
│   ├── core/
│   │   ├── options.lua       # 编辑器全局选项与 Python 缩进
│   │   ├── keymaps.lua       # 全局快捷键
│   │   └── runner.lua        # 跨平台 F10 编译运行
│   ├── plugins/
│   │   └── plugin-list.lua   # 所有插件声明、依赖和加载条件
│   ├── config/               # 各插件实际 setup 与快捷键
│   └── codex/                # Codex 命令、终端与 :checkhealth codex
├── docs/                     # 中文总文档、平台文档和插件单页
└── tests/                    # Codex 与 Windows 配置的无界面测试
```

启动链为：

```text
init.lua
  ├─ core.options
  ├─ core.keymaps
  ├─ 引导并加载 lazy.nvim
  │    └─ lua/plugins/plugin-list.lua
  │         ├─ lua/config/*.lua
  │         └─ lsp/*.lua
  └─ 注册 <F10> core.runner.run_current
```

`plugin-list.lua` 决定插件是否安装、何时加载；`config/*.lua` 决定本项目真正开启了哪些
功能。仅在 `lazy-lock.json` 出现、但不在插件声明或依赖树中的目录，不能据此认定已启用。

## 基础行为

- Leader 键为空格。
- 行号、当前行、搜索增量高亮、智能大小写、鼠标和自动换行已开启。
- 普通文件使用 2 空格展开 Tab；Python buffer 使用 4 空格。
- `autochdir` 会把当前工作目录切到正在编辑的文件目录。运行 Git、Go 或脚本命令前先用
  `:pwd` 确认目录；需要项目根目录时可用 `:cd /path/to/project`。
- 文件重新打开时恢复上次光标位置。
- `conceallevel=3` 会隐藏 Markdown 等文件的部分标记；需要看原文可临时执行
  `:set conceallevel=0`。
- Perl 和 Ruby provider 被显式关闭；这不影响编辑 Perl/Ruby 文件，但依赖这些 provider
  的插件无法工作。

## 核心快捷键

下面的 `<Space>` 表示 Leader。插件专用按键请到[插件索引](docs/README.md)查看。

### 文件、窗口和标签页

| 模式 | 按键 | 功能 |
| --- | --- | --- |
| 普通/可视 | `Ctrl-s` | 保存 |
| 普通/可视 | `Ctrl-q` | 退出当前窗口；有未保存内容时会拒绝 |
| 普通/可视 | `R` | 重新载入配置并刷新 Airline |
| 普通 | `spl` / `spr` | 左侧 / 右侧垂直分屏 |
| 普通 | `spu` / `spb` | 上方 / 下方水平分屏 |
| 普通 | `↑` / `↓` | 当前窗口高度增 / 减 5 |
| 普通 | `←` / `→` | 当前窗口宽度减 / 增 5 |
| 普通 | `<Space>h/j/k/l` | 移动到左/下/上/右窗口 |
| 普通 | `tn` | 新标签页 |
| 普通 | `tl` / `tr` | 上一个 / 下一个标签页 |
| 普通 | `tt` | 切换文件树 |
| 普通 | `<Space>f` | 在文件树定位当前文件 |
| 普通 | `L` / `T` | 撤销树 / 代码大纲 |

### 移动和编辑

| 模式 | 按键 | 功能 |
| --- | --- | --- |
| 普通/可视 | `Ctrl-j` / `Ctrl-k` | 下/上移动 5 行并居中 |
| 可视 | `Ctrl-j` / `Ctrl-k` | 选中行整体下/上移；覆盖上一项的可视模式含义 |
| 普通 | `G`、`n`、`N` | 跳转后把目标置于屏幕中部 |
| 普通 | `<Space><Space>` | 找到下一个 `<++>`，删除占位符并进入插入模式 |
| 普通 | `<Space>nh` | 清除搜索高亮 |
| 普通 | `<Space>sc` | 切换拼写检查 |
| 普通 | `<Space>rc` | 打开本机 Neovim 配置入口 |
| 终端 | `Ctrl-t` | 返回 Neovim 普通模式 |

### 代码导航、格式化和调试

LSP 按键只在语言服务器成功附着后存在。

| 按键 | 功能 |
| --- | --- |
| `gd` / `gr` / `gi` / `gy` | 定义 / 引用 / 实现 / 类型定义 |
| `gD` | 自动选择水平或垂直分屏后跳定义 |
| `K` | 悬浮文档 |
| `<Space>rn` / `<Space>ca` | 重命名 / 代码操作 |
| `[g` / `]g` | 上一处 / 下一处诊断 |
| `[f` / `]f` | 当前文档符号的起点 / 终点 |
| `<Space>lf` | LSP 格式化 |
| `<Space>fm` | Conform 格式化当前文件或选择区 |
| `<Space>db` / `<Space>dB` | 普通断点 / 条件断点 |
| `F2` / `F3` / `F4` / `F5` | 继续、步入、步过、步出 |
| `F6` / `F7` | 重新开始、终止调试 |

详见 [nvim-lspconfig](docs/plugins/language/nvim-lspconfig.md)、
[Conform](docs/plugins/language/conform.nvim.md) 和
[nvim-dap](docs/plugins/debugging/nvim-dap.md)。

### Git、Markdown 与外部 CLI

| 按键 | 功能 |
| --- | --- |
| `<Space>ph` | 预览当前 Git 修改块 |
| `<Space>[h` / `<Space>]h` | 上一 / 下一修改块 |
| `<Space>rh` | 恢复当前修改块；会丢弃该块的未提交修改 |
| `<Space>td` | 切换显示已删除行 |
| `F8` / `F9` | 启动 / 停止浏览器 Markdown 预览 |
| `<Space>pi` | 从系统剪贴板保存图片并插入 Markdown 链接 |
| `<Space>tm` | 切换 Markdown 表格模式 |
| `<Space>g` | 在右侧终端运行 `gemini` |
| `<Space>ac` / `<Space>ar` | 开关 Codex / 恢复 Codex 历史会话 |
| `F10` | 按 filetype 保存、编译或运行当前文件 |

`<Space>pw` 会直接打开个人密码文档（Linux 为 `~/Documents/pswd.md`，Windows 为
`$USERPROFILE/Documents/pswd.md`）。这是仓库作者的个人路径；不需要此功能时应删除映射，
也不要把真实密码文件提交到 Git。

## F10 一键运行的真实范围

`F10` 在执行前保存当前文件。编译器和解释器参数以 argv 传递，因此 Windows 路径中的
空格不会被 shell 拆开；复杂项目仍更适合使用项目自身的构建命令。

| filetype | 当前命令或行为 | 额外依赖 |
| --- | --- | --- |
| `c` | `gcc 文件 -o 输出` 后运行 | gcc |
| `cpp` | `g++ -std=c++11 -Wall ...` 后运行 | g++ |
| `cs` | `mcs` 后 `mono` | Mono |
| `java` | `javac` 后按 classpath 运行主类 | JDK |
| `sh` | `bash 文件` | Bash |
| `python` | Windows 优先 `python`，其他平台优先 `python3` | Python |
| `html` | 用 `vim.ui.open()` 交给系统默认程序 | 默认浏览器 |
| `markdown` / `vimwiki` | `:MarkdownPreview` | markdown-preview.nvim |
| `tex` | `:VimtexStop`、`:VimtexCompile` | 当前未声明 vimtex |
| `dart` | `:CocCommand flutter...` | 当前启动链未启用 coc.nvim |
| `javascript` | `node --trace-warnings 文件` | Node.js |
| `racket` | `racket 文件` | Racket |
| `go` | `go run .` | Go；受 `autochdir` 影响 |

这张表描述现状，并不表示所有语言运行时都已安装。命令生成与执行逻辑位于
`lua/core/runner.lua`。

## LSP、补全、格式化和检查的关系

| 层 | 本项目组件 | 作用 |
| --- | --- | --- |
| 工具安装 | Mason + mason-lspconfig | 下载 LSP 与可选外部程序 |
| 语言服务 | Neovim LSP + nvim-lspconfig | 跳转、悬浮、诊断、重命名 |
| 补全 | nvim-cmp + cmp-buffer/path/nvim-lsp | 显示和选择候选 |
| 格式化 | conform.nvim | 保存时调用 black/isort/prettier/stylua/sqlfluff |
| 独立检查 | nvim-lint | SQL 保存、进入 buffer、退出插入时运行 sqlfluff |
| 语法树 | nvim-treesitter | 结构化高亮，并服务 Markdown 与调试显示 |

Mason 安装成功不等于 LSP 已附着；插件安装成功也不等于外部 formatter 已安装。排查时依次看：

```vim
:Lazy
:Mason
:checkhealth
:checkhealth vim.lsp
:lua vim.print(vim.lsp.get_clients({bufnr = 0}))
:ConformInfo
:LspLog
```

## SQL 数据库配置

`lsp/sqls.lua` 定义了四个 MySQL 连接别名，不保存凭据，只读取环境变量。使用前在启动
Neovim 的 shell 中设置相应值：

| 别名 | 变量后缀 | 必需变量 |
| --- | --- | --- |
| `tongyan` | `TY` | `DB_USER_TY`、`DB_PASSWORD_TY`、`DB_HOST_TY`、`DB_PORT_TY`、`DB_NAME_TY` |
| `tongyan_test` | `TYTEST` | 同样五项，以 `TYTEST` 结尾 |
| `platform_st` | `ST` | 同样五项，以 `ST` 结尾 |
| `platform_st_test` | `STTEST` | 同样五项，以 `STTEST` 结尾 |

例如在当前 Linux shell 临时设置：

```bash
export DB_USER_TY='user'
export DB_PASSWORD_TY='replace-me'
export DB_HOST_TY='127.0.0.1'
export DB_PORT_TY='3306'
export DB_NAME_TY='database'
nvim query.sql
```

不要把密码写进本仓库。SQL 缓冲区使用 `<Space>swc` / `<Space>swd` 切换连接和数据库，
`<Space>ssc` / `<Space>ssd` / `<Space>sst` 查看连接、数据库和表，`<Space>se` 执行全部或可视
选中的 SQL 行，`<Space>sv` 纵向显示结果。这些快捷键依赖 sqls.nvim 注册缓冲区命令；
Windows 专项测试会同时检查命令存在、快捷键范围和 SQLS 格式化已关闭。排错见
[sqls.nvim](docs/plugins/language/sqls.nvim.md)。

需要像数据库管理软件一样浏览并编辑表数据时，按 `<Space>sg` 打开 Dadbod Grip。单元格修改会
先暂存，可审核生成的 SQL 后再用一个事务提交。MySQL 模式要求系统能够找到 `mysql.exe`，
安装和操作步骤见 [dadbod-grip.nvim](docs/plugins/language/dadbod-grip.nvim.md)。

## Markdown 与 Vimwiki

Vimwiki 在 Linux 使用 `~/vimwiki/`，在 Windows 使用 `E:/@home/usharbisin/vimwiki/`，语法为 Markdown，扩展名为 `.md`。浏览器预览、编辑器内
渲染、图片粘贴和表格编辑是四套独立能力：

- `render-markdown.nvim` 美化当前 Neovim buffer；
- `markdown-preview.nvim` 用 F8/F9 控制浏览器预览；
- `img-clip.nvim` 把剪贴板图像转为 AVIF，放进当前目录的 `.markdown_images/`；
- `diagram.nvim` 调用 Mermaid、PlantUML、D2 或 Gnuplot 渲染代码块；
- `vim-table-mode` 用 `<Space>tm` 开关表格排版。

两个系统都使用 `stdpath('config')` 定位 Markdown CSS，并交给系统默认浏览器打开预览。
Vimwiki 根目录按系统选择，详细说明见[Markdown 插件分类](docs/README.md#markdown-与知识库)。

## 更新、回滚与诊断

日常更新前先提交自己的配置改动。`lazy-lock.json` 是各系统本地维护的文件，不参与 Git 提交：

```bash
git status
git pull --ff-only
```

在 Neovim 内运行 `:Lazy sync`。需要回退本机插件时，可用本地锁文件和 Lazy 界面的 restore；
Mason 的 LSP、formatter 和调试器有独立生命周期，
需在 `:Mason` 中检查。

常见问题：

1. 图标是方块：终端使用并选择 Nerd Font。
2. 首次启动卡在下载：检查 GitHub 网络、`:Lazy log` 与代理环境。
3. LSP 不工作：确认 `:Mason` 已安装、`:checkhealth vim.lsp` 正常，且从真实项目打开文件。
4. Tree-sitter 无高亮：执行 `:checkhealth nvim-treesitter` 和 `:TSUpdate`；配置用 `pcall`
   静默跳过缺失 parser，所以未弹错不代表成功。
5. 图片粘贴失败：检查系统剪贴板工具和 `magick`，并确认 ImageMagick 支持 AVIF。
6. 保存时报 formatter 不存在：执行 `:ConformInfo`，再用 Mason 安装对应工具。
7. 某快捷键行为不同：用 `:verbose nmap 按键` 或 `:verbose imap 按键` 查最后覆盖来源。

## 本机验证结果

当前文档记录了以下验证：

- Arch Linux / Neovim 0.12.5 与 Windows 11 / Neovim 0.12.4 均能完整读取配置并退出；
- Windows 的 Lazy 注册 66 个插件条目，锁文件中的插件均有安装目录；
- `:Codex` / `:CodexResume` 命令已注册；
- Windows 配置列出的 14 个 Tree-sitter parser 均可加载，6 个 Mason LSP 均能附着；
- 带空格路径的 C 文件可由 F10 编译运行，GDB DAP 可命中 C 断点并正常退出。

数据库网络、未安装的可选编译器和所有 GUI/剪贴板组合没有逐一验证。平台文档提供了可复现
的检查步骤，并区分必需依赖与可选工具。
