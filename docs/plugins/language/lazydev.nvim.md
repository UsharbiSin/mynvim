[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# lazydev.nvim：Neovim Lua 开发辅助

**仓库：** `folke/lazydev.nvim`。声明按 `ft="lua"` 加载，`opts` 由 Lazy 执行 setup；此外 [mason.lua](../../../lua/config/mason.lua) 主动 `require("lazydev")`，所以实际可能被提前加载。配置见 [plugin-list.lua](../../../lua/plugins/plugin-list.lua)。

## 当前功能

为 Lua language server 提供 Neovim API 与运行时插件库的信息，让编辑 `init.lua`、`lua/config/*.lua` 时更容易得到 API 参数与文档。它不替代 Lua LSP；Mason 中 `lua-language-server` 仍需成功安装并附着。

本项目唯一额外库声明：

```lua
library = {
  { path = "luvit-meta/library", words = { "vim%.uv" } },
}
```

文件中出现 `vim.uv` 时，按需把 [luvit-meta](../dependencies/luvit-meta.md) 类型库提供给服务。没有把整个运行时文件树硬塞给 LuaLS，也没有配置上游示例中的专用 `lazydev` cmp source；普通 Lua 候选通过已有 LSP source 展示。

## 首次使用

打开本仓库的 Lua 文件，输入 `vim.api.` 测试 API 补全；对 `vim.uv.fs_stat` 用 `K` 看文档。优先确认 `:checkhealth vim.lsp` 中 LuaLS 附着，随后检查 Lazy 中 lazydev 和 luvit-meta 是否安装。

## 排错与平台

若报 `Undefined global vim` 或 API 不完整，检查当前项目 `.luarc.json` / `.luarc.jsonc`、LuaLS 日志以及 lazydev 是否运行。更改库配置后重启对应语言服务或 Neovim。不要单独安装 luvit 运行时来解决类型库问题，它们用途不同。

main 在两个系统配置一致，无插件专属快捷键；Windows 实机已确认 Lua LSP 能附着。[上游使用与库配置](https://github.com/folke/lazydev.nvim)
