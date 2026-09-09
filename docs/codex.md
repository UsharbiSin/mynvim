# 在 Neovim 中使用 Codex

[返回项目使用说明](../README.md) · [插件索引](README.md)

本配置采用 **官方 Codex CLI + 已有的 Snacks terminal**。Arch Linux 和 Windows 11 原生
Neovim 使用同一份 Codex 模块，并按操作系统选择启动命令和路径。

## 方案选择

| 方案 | 适用场景 | 本仓库的选择 |
| --- | --- | --- |
| Codex CLI + Snacks | 使用官方终端交互、登录、会话和工具；复用已有插件 | 默认方案，无新增插件依赖 |
| Sidekick 的 CLI 功能 | 需要统一管理多种 AI CLI 和编辑器上下文 | 当前只接入 Codex，暂不增加这一层 |
| CodeCompanion + ACP 适配器 | 更看重编辑器内聊天、上下文和编辑交互 | 功能更丰富，但需额外维护插件和适配器 |

Codex 负责项目级理解、修改、运行命令和审查；现有 LSP、nvim-cmp、Conform、DAP、
Gitsigns 和 Fugitive 继续负责原来的功能。本方案不提供 AI 行内补全，也不会把 Codex
伪装成 LSP 或 nvim-cmp 补全源。

## 安装和登录

需要 Neovim 0.11 或更新版本，以及 `lazy-lock.json` 中锁定的 Snacks 版本。
本模块已经按仓库中的 Snacks 提交检查接口，无需为接入 Codex 批量升级插件。

在两台机器的系统终端中分别安装 CLI。已有 Node.js/npm 时可使用同一条命令：

```sh
npm install -g @openai/codex
codex --version
codex login
codex login status
```

登录时选择 **Sign in with ChatGPT**，使用账号可用的 Codex 权益；额度和模型以该
账号的 CLI 显示为准。API Key 是另一种认证和计费方式，不需要为了这套配置额外申请。
配置不写入任何登录凭据，也不固定模型；在 CLI 中用 `/model` 选择可用模型，用
`/permissions` 查看或更改当前权限。

也可使用[官方安装页面](https://learn.chatgpt.com/docs/codex/cli)提供的独立安装器。
安装后重启 Neovim，使它获得新的 PATH，然后执行 `:checkhealth codex`。

### Arch Linux

在运行 Neovim 的同一个 Linux 环境中安装、登录。终端检查通过后，打开项目中的文件，
按 `<Space>ac` 即可。

### Windows 11

在 Windows 本机安装 Codex，与原生 Neovim 使用同一套文件路径、Git 和构建工具。
当前官方支持原生 Windows；首次运行请按 CLI 提示完成 Windows sandbox 设置。
本配置继承 CLI 自身的权限设置。

启动器优先寻找 `codex.exe`。如果通过 npm 安装并得到 `codex.cmd`，模块会定位同级
`node_modules/@openai/codex/bin/codex.js`，通过 `node.exe` 启动；不依赖把 shell 改成
PowerShell，也无需修改系统执行策略。路径和参数使用数组传递，支持含空格的路径。

若使用自定义安装位置，可在 `init.lua` 加载插件前指定，例如：

```lua
vim.g.codex_cmd = { "C:/Tools/Codex/codex.exe" }
-- 或使用自己安装的 Node 和 Codex JS 入口：
-- vim.g.codex_cmd = { "C:/Program Files/nodejs/node.exe", "C:/Tools/codex/bin/codex.js" }
```

如果项目的构建环境本来就在 WSL，建议把 Neovim、Codex、Git 和项目全部放到 WSL 内，
并使用 Linux 配置。本模块不会自动从原生 Windows Neovim 调用 WSL Codex 或转换路径。

## 快捷键和工作流程

本仓库的 `<leader>` 是空格。

| 入口 | 功能 |
| --- | --- |
| `<Space>ac` / `:Codex` | 在右侧打开或隐藏当前项目的 Codex；隐藏后进程仍运行 |
| `<Space>ar` / `:CodexResume` | 没有活动进程时运行 `codex resume`，选择历史会话 |
| Codex 内 `<C-t>` | 沿用已有快捷键，从终端输入模式返回 Neovim 普通模式 |
| Codex 普通模式下 `q` | 隐藏面板；再次 `<Space>ac` 打开 |
| Codex 普通模式下 `i` / `a` | 进入终端输入模式 |
| `:checkhealth codex` | 检查可执行文件解析和 Snacks 模块；不会触发登录或模型请求 |

如果当前项目已有活动进程，恢复入口会聚焦该进程；需要切换历史会话时，在 Codex 内
使用 `/resume`。退出并重新打开 Neovim 后，使用恢复入口继续之前的工作。

首次打开 Codex，以及从其他窗口切回 Codex 时，窗口会停留在 Neovim 普通模式，方便
滚动、复制或直接切换窗口。需要向 CLI 输入内容时按 `i` 或 `a`；输入完成后可按
`<C-t>` 回到普通模式。

1. 先保存准备让 Codex 读取的文件；CLI 读取的是磁盘文件，不是未保存的 Neovim buffer。
2. `<Space>ac` 打开 Codex，在输入框中描述任务，必要时提供文件相对路径和行号。
3. 修改期间按 `<C-t>` 返回普通模式，再用 `<Space>h` 回到代码窗口。未修改的 buffer
   会通过 `checktime` 刷新；有未保存编辑的 buffer 会保留内容，需要自行对比合并。
4. 用已有 `<Space>ph`、`<Space>[h`、`<Space>]h` 检查修改块，或运行 `:Git diff` 查看
   项目差异，再决定是否提交。新文件可在 `:Git status` 中检查。

会话工作目录取当前文件向上最近的 `.git` 根目录，兼容 Git worktree 的 `.git` 文件。
没有 Git 根目录时使用文件所在目录；无名或特殊 buffer 则回退到 Neovim 当前目录。
因此开启 `autochdir` 时，在同一个仓库的不同子目录间切换仍会复用同一会话。

## 变更文件

| 文件 | 功能 |
| --- | --- |
| `lua/plugins/plugin-list.lua` | 将 Snacks 声明为图片预览和 Codex 的共用依赖，移除多余的 Markdown 文件类型触发 |
| `lua/config/snacks.lua` | 开启 terminal 模块并初始化 Codex 命令 |
| `lua/config/codex.lua` | 项目根目录、跨平台启动器、会话复用和恢复、外部文件刷新 |
| `lua/core/keymaps.lua` | 注册 Codex 快捷键，由已有 which-key 展示描述 |
| `lua/codex/health.lua` | 提供 `:checkhealth codex` |
| `tests/codex.lua` | 使用真实 Neovim 和锁定的 Snacks 验证会话与文件刷新；模拟 Windows 路径解析 |
| `docs/codex.md` | 安装、平台选择、使用方法和验证说明 |

`lazy-lock.json`、LSP、nvim-cmp、Mason、Git 插件和已有 Gemini 入口无需修改。

## 验证

插件已经安装时，从仓库根目录运行：

```sh
nvim --headless -u NONE -l tests/codex.lua
```

测试默认读取 `stdpath('data')/lazy/snacks.nvim`，也可通过 `SNACKS_RTP` 环境变量指定
锁定版本的插件目录。测试使用本机 Neovim 子进程模拟持续运行的 CLI，不调用模型。
Windows 11 实机已通过 30 项 Codex 集成检查，health 能解析 npm 安装的 JS 入口；登录状态
仍应在系统终端用 `codex login status` 单独确认。

## 参考

- [Codex CLI 安装与使用](https://learn.chatgpt.com/docs/codex/cli)
- [Codex 登录方式](https://learn.chatgpt.com/docs/auth)
- [Windows sandbox](https://learn.chatgpt.com/docs/windows/windows-sandbox)
- [Codex 命令与会话恢复](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
- [Snacks terminal 接口](https://github.com/folke/snacks.nvim/blob/882c996cf28183f4d63640de0b4c02ec886d01f2/docs/terminal.md)
- [Sidekick](https://github.com/folke/sidekick.nvim)
- [CodeCompanion](https://github.com/olimorris/codecompanion.nvim)
