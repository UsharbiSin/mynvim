-- ==========================================
-- lua/plugins/mason.lua
-- 专门负责底层 LSP Server、Linter、Formatter 的下载与包管理
-- ==========================================

-- 初始化 Mason 核心面板 (提供 :Mason 命令和基础图形界面)
require("mason").setup({
  ui = {
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗"
    }
  }
})

-- 初始化桥接插件，并告诉它需要自动下载哪些 Server
-- 必须配置在这里，Mason 才会真正去自动下载它们，避免 not executable 错误
require("mason-lspconfig").setup({
  ensure_installed = {
    "pylsp",  -- Python
    "html",   -- HTML
    "jsonls", -- JSON
    "sqlls",  -- SQL
    "lua_ls", -- Lua
    "clangd"  -- C/C++
  },
  -- 自动安装 ensure_installed 中配置的 servers
  automatic_installation = true,
})

require("lazydev")
require("config.lsp")
