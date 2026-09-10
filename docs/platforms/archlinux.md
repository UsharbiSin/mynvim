# Arch Linux 安装与配置

[返回项目使用说明](../../README.md) · [插件索引](../README.md)

本文适用于原生 Arch Linux。Arch Linux 与 Windows 11 均以 Neovim 0.12.5 为当前运行版本；
Arch Linux 已做过无界面启动检查。锁定的
`nvim-treesitter` 要求 Neovim 至少 0.11、Tree-sitter CLI 至少 0.26.1。

## 1. 备份旧配置

先退出所有 Neovim 实例：

```bash
backup_stamp=$(date +%Y%m%d-%H%M%S)
test ! -e ~/.config/nvim || mv ~/.config/nvim ~/.config/nvim.bak-$backup_stamp
test ! -e ~/.local/share/nvim || mv ~/.local/share/nvim ~/.local/share/nvim.bak-$backup_stamp
test ! -e ~/.local/state/nvim || mv ~/.local/state/nvim ~/.local/state/nvim.bak-$backup_stamp
test ! -e ~/.cache/nvim || mv ~/.cache/nvim ~/.cache/nvim.bak-$backup_stamp
```

只想替换配置而保留已下载插件时，仅备份 `~/.config/nvim`。遇到难以解释的旧缓存问题时，
再备份 data/state/cache 目录；不要直接删除，以便恢复。

## 2. 安装基础依赖

```bash
sudo pacman -Syu
sudo pacman -S --needed neovim git curl unzip base-devel tree-sitter-cli nodejs npm
sudo pacman -S --needed imagemagick python libreoffice-fresh poppler
```

- `base-devel` 提供构建 Tree-sitter parser 和部分插件所需的工具链。
- `nodejs` / `npm` 用于构建 markdown-preview.nvim，也可安装 Codex CLI。
- `imagemagick` 用于 img-clip 的 AVIF 转换和 Snacks 图片转换。
- Wayland 剪贴板安装 `wl-clipboard`；X11 安装 `xclip` 或 `xsel`。
- Undotree 使用 `diffutils`；Tagbar 使用 `universal-ctags`；ASCII 大字功能使用 `figlet`。
- 字体选择任一 Nerd Font，并在终端设置里真正选中该字体。

```bash
sudo pacman -S --needed diffutils universal-ctags figlet
# Wayland 二选一示例
sudo pacman -S --needed wl-clipboard
```

按使用语言再装：`gcc`/`clang`、`gdb`/`lldb`、`go`、JDK、Racket、Mono 等。F10 不会替你
安装编译器。Snacks 行内图片还取决于终端图像协议；Kitty、WezTerm、Ghostty 等需按上游
说明设置，普通终端可能只能显示悬浮或无法显示。

## 3. 克隆配置

```bash
git clone https://github.com/UsharbiSin/mynvim.git ~/.config/nvim
nvim
```

首次启动的 `init.lua` 会克隆 stable lazy.nvim，随后 Lazy 根据 `plugin-list.lua` 安装插件，
并在本地生成已被 Git 忽略的 `lazy-lock.json`。网络中断时重新启动并执行：

```vim
:Lazy sync
:Lazy log
```

## 4. 安装语言服务和外部工具

Mason 会自动请求 `pylsp`、`html`、`jsonls`、`sqls`、`lua_ls`、`clangd`。在 `:Mason`
中等待它们全部完成。再安装保存格式化与调试需要的工具：

```vim
:MasonInstall black isort prettier stylua sqlfluff debugpy
```

SQLS 的 Mason 包需要 Go 工具链时，先 `sudo pacman -S go`，重开 Neovim 后重试。若要把
`K` 打开的 LSP 文档翻译为中文，再执行
`go install github.com/SantaChains/LspProxy@latest`，并确保 Go bin 目录在 PATH 中。Python
LSP 配置声明了 flake8、mypy/isort 插件，但布尔配置不会安装 Python 扩展；应在 pylsp 实际
运行环境中确认 `python-lsp-server[all]`、`pylsp-mypy` 等是否存在，并核对本仓库的插件键名。

## 5. 修改个人路径

首次使用前检查：

1. `lua/config/markdown.lua` 的 Firefox、CSS 和 Vimwiki 图片绝对路径。
2. `lua/config/debugging.lua` 的 debugpy 适配器固定为
   `/home/usharbisin/.virtualenvs/debugpy/bin/python`。改为自己的 debugpy Python，或使用
   Mason 安装目录。
3. `lua/core/keymaps.lua` 的 `<Space>pw` 指向个人密码文档。
4. `lua/config/vimwiki.lua` 的 `~/vimwiki/`。
5. `lsp/sqls.lua` 的数据库别名与环境变量。不要把密码直接写进 Lua。
6. `<Space>g` 需要 PATH 中有 `gemini`；不用就删除该映射。

## 6. Codex

当前 OpenAI 官方 Linux 安装器：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
codex
```

首次运行选择可用的登录方式。重启 Neovim，让它继承更新后的 PATH，再执行
`:checkhealth codex`。`<Space>ac` 开关当前项目终端，`<Space>ar` 运行 `codex resume`。
完整说明见 [Codex 文档](../codex.md)。

## 7. 验证

```bash
nvim --version
tree-sitter --version
git --version
node --version
npm --version
magick --version
```

Neovim 内：

```vim
:checkhealth
:checkhealth nvim-treesitter
:checkhealth vim.lsp
:checkhealth snacks
:checkhealth codex
:Lazy
:Mason
```

分别打开 `.lua`、`.py`、`.c`、`.md`、`.sql` 文件，检查 `:set filetype?`、
`:lua vim.print(vim.lsp.get_clients({bufnr=0}))`，再测试格式化、Markdown 预览和图片粘贴。

## 8. 已知限制

- F10 对文件名没有做 shell 转义，含空格路径可能失败。
- Markdown 的 F10 调用未安装的 `InstantMarkdownPreview`；使用 F8/F9。
- TeX、Dart 分支引用了未声明的 Vimtex/Coc 命令。
- Python DAP 使用作者绝对路径；nvim-dap-python 虽安装但没有调用其 setup。
- SQLS 快捷键、SQL Runner 与 Dadbod Grip 已纳入跨平台配置，但尚未在 Linux 实机
  验证。后续需安装 `mysql` 客户端，运行 `:checkhealth dadbod-grip`，并使用测试库确认连接、
  查询结果网格和事务提交。
- diagram.nvim 与 image.nvim 已纳入跨平台配置，但尚未在 Linux 实机验证。后续需
  在支持图像协议的终端中检查 ImageMagick，并按需验证 Mermaid、PlantUML、D2 或 Gnuplot。
- `autochdir` 会改变终端和构建命令工作目录。
