---@brief
---
--- https://github.com/sqls-server/sqls
---
--- ```lua
--- vim.lsp.config('sqls', {
---   cmd = {"path/to/command", "-config", "path/to/config.yml"};
---   ...
--- })
--- ```
--- Sqls can be installed via `go install github.com/sqls-server/sqls@latest`. Instructions for compiling Sqls from the source can be found at [sqls-server/sqls](https://github.com/sqls-server/sqls).

---@type vim.lsp.Config
return {
  cmd = { "sqls" },
  filetypes = { "sql", "mysql" },
  -- 全局配置不包含密码，启动 SQLS 后再异步从系统凭据库读取。
  on_init = require("config.sql-credentials.sqls").on_init,
  handlers = {
    ["textDocument/publishDiagnostics"] = function() end,
  },
  settings = { sqls = { connections = {} } },
}
