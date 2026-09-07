[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# luvit-meta：vim.uv 类型元数据

仓库：`Bilal2453/luvit-meta`，标记为 lazy，供 lazydev.nvim 在 Lua 文件出现 `vim.uv` 时加载
其 `library`。它给 Lua language server 提供 libuv/Luv 类型信息，不是运行时实现。

本项目通过 lazydev 的 `words = { "vim%.uv" }` 条件加入元数据。它不会安装系统 libuv，也
没有命令或快捷键。编辑 Neovim Lua 时 `vim.uv` 补全缺失，检查 lazydev、lua_ls 与此条目。

上游：[luvit-meta](https://github.com/Bilal2453/luvit-meta)。
