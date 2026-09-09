[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# mason.nvim：语言工具安装管理

**仓库：** `williamboman/mason.nvim`（上游现位于 mason-org）。**加载：** 启动时加载；配置见 [mason.lua](../../../lua/config/mason.lua)，声明见 [plugin-list.lua](../../../lua/plugins/plugin-list.lua)。

## 本项目负责什么

Mason 下载语言服务器、格式化器、检查器、调试适配器；插件代码由 Lazy 安装。Mason 本身不显示补全、不执行格式化、不编译项目。本项目通过 [mason-lspconfig](mason-lspconfig.nvim.md) 自动安装六个 LSP，其他工具需按需安装。

## 首次准备与安装

先完成根目录说明中的 Neovim、Git、Node.js/npm、Python、解压工具与网络配置。Arch 需要可用的 curl、tar、gzip、unzip；Windows 11 需要 PowerShell、Git、GNU tar 及受支持的解压工具，例如 7-Zip。具体包有自己的运行时要求，检查 `:checkhealth mason`。[上游依赖说明](https://github.com/mason-org/mason.nvim#requirements)

在 Neovim 内执行：

```vim
:Mason
:MasonUpdate
:MasonInstall black isort prettier stylua sqlfluff
```

最后一条补齐本项目 [Conform](conform.nvim.md) 和 [nvim-lint](nvim-lint.md) 所需程序；调试 Python 时另执行 `:MasonInstall debugpy`。调试配置从 Mason debugpy 目录按系统解析适配器路径，见 [DAP](../debugging/nvim-dap.md)。

Mason 的可执行文件目录默认加入 **Neovim 进程** 的 PATH。终端里找不到 `black`，并不等于 Neovim 内找不到；安装目录由 `stdpath("data")` 决定：

```vim
:lua print(vim.fn.stdpath("data") .. "/mason")
:lua print(vim.fn.exepath("black"))
```

## 日常操作

`:Mason` 面板按 `g?` 查看实际版本帮助；`:MasonLog` 查看下载/安装错误。对照包状态等待安装完成，再打开相应代码文件。配置中的 ✓、➜、✗ 分别代表已安装、处理中和未安装。[上游命令](https://github.com/mason-org/mason.nvim#commands)

## 排错与平台说明

- 六个 LSP 已安装仍无提示：检查 [LSP 连接](nvim-lspconfig.md)，安装成功与成功附着是两个步骤。
- npm/pip/解压错误：先看 Mason 日志里的首个失败程序，在启动 Neovim 的同一个 shell 检查它。
- 项目没有锁定 Mason 下载的全部外部工具版本；`lazy-lock.json` 锁定的是 Neovim 插件提交。
- Windows 实机已确认六个 LSP 与 debugpy 安装目录存在；Mason UI 可正常读取状态。
