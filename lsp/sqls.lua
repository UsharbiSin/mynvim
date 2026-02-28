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

local function get_dsn(user, pass, host, port, name)
  return string.format("%s:%s@tcp(%s:%s)/%s",
    os.getenv(user), os.getenv(pass), os.getenv(host), os.getenv(port), os.getenv(name)
  )
end

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
  settings = {
    sqls = {
      connections = {
        {
          alias = "tongyan",
          driver = "mysql",
          dataSourceName = get_dsn("DB_USER_TY", "DB_PASSWORD_TY", "DB_HOST_TY", "DB_PORT_TY", "DB_NAME_TY"),
        },
        {
          alias = "tongyan_test",
          driver = "mysql",
          dataSourceName = get_dsn("DB_USER_TYTEST", "DB_PASSWORD_TYTEST", "DB_HOST_TYTEST", "DB_PORT_TYTEST", "DB_NAME_TYTEST"),
        },
        {
          alias = "platform_st",
          driver = "mysql",
          dataSourceName = get_dsn("DB_USER_ST", "DB_PASSWORD_ST", "DB_HOST_ST", "DB_PORT_ST", "DB_NAME_ST"),
        },
        {
          alias = "platform_st_test",
          driver = "mysql",
          dataSourceName = get_dsn("DB_USER_STTEST", "DB_PASSWORD_STTEST", "DB_HOST_STTEST", "DB_PORT_STTEST", "DB_NAME_STTEST"),
        },
      }
    }
  },
}
