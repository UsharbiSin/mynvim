[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# cmp-nvim-lsp：把 LSP 候选交给补全菜单

**仓库：** `hrsh7th/cmp-nvim-lsp`。作为 nvim-cmp 依赖加载；[nvim-cmp.lua](../../../lua/config/nvim-cmp.lua) 中源名为 `nvim_lsp`。

## 功能与当前接入程度

它读取已附着语言服务器提供的候选，例如变量、函数、参数提示，交给 [nvim-cmp](nvim-cmp.md) 展示。自身既不安装服务器，也不做代码分析；先保证 [LSP](nvim-lspconfig.md) 正常。

本项目启用了该源，但未在公共 LSP 配置中合并 `require("cmp_nvim_lsp").default_capabilities()`。该辅助函数用于向服务器声明 cmp 可支持的候选能力，安装插件本身不会代替调用。[上游能力说明](https://github.com/hrsh7th/cmp-nvim-lsp#capabilities)

## 使用与验证

在 Lua 文件输入 `vim.api.` 后手动触发补全；`:CmpStatus` 查看 `nvim_lsp` 是否可用。把光标放在某个函数上用 `K` 测试 LSP，再区分是补全源问题还是服务器问题。所有选择键复用 nvim-cmp，没有独立快捷键。

## 需要完整候选能力时

以下为 **可选修改示意，仓库当前未配置**，应放在服务器启用前：

```lua
vim.lsp.config("*", {
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})
```

启用更完整能力后，服务器可能返回 snippet。应同时完善 cmp 的 snippet 展开设置并验证所用 Neovim 支持相应 API；不要只复制 capabilities 后就认定片段展开完整。上游也提示，这组能力可能改变内置 omnifunc 的兼容性。

main 在两个系统使用相同配置；Windows 实机已确认六个 LSP 能附着。没有 LSP 候选优先检查程序 PATH、当前 filetype、root 与附着状态。
