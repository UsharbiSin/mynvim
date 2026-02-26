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

local db_user = os.getenv("DB_USER_TY")
local db_pass = os.getenv("DB_PASSWORD_TY")
local db_host = os.getenv("DB_HOST_TY")
local db_port = os.getenv("DB_PORT_TY")
local db_name = os.getenv("DB_NAME_TY")

local dsn = string.format("%s:%s@tcp(%s:%s)/%s", db_user, db_pass, db_host, db_port, db_name)

---@type vim.lsp.Config
return {
  cmd = { 'sqls' },
  filetypes = { 'sql', 'mysql' },
  -- 禁用格式化与语法诊断
  handlers = {
    ["textDocument/publishDiagnostics"] = function() end,
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
  root_markers = { 'config.yml' },
  settings = {
    sqls = {
      connections = {
        {
          alias = "tongyan",
          driver = "mysql",
          dataSourceName = dsn,
        }
      }
    }
  },
}
