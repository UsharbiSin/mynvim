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

local function connection(alias, suffix)
  local values = {}
  for _, field in ipairs({ "USER", "PASSWORD", "HOST", "PORT", "NAME" }) do
    local value = os.getenv("DB_" .. field .. "_" .. suffix)
    if not value or value == "" then
      return nil
    end
    values[field] = value
  end

  return {
    alias = alias,
    driver = "mysql",
    dataSourceName = string.format(
      "%s:%s@tcp(%s:%s)/%s",
      values.USER,
      values.PASSWORD,
      values.HOST,
      values.PORT,
      values.NAME
    ),
  }
end

local connections = {}
for _, item in ipairs({
  { "tongyan", "TY" },
  { "tongyan_test", "TYTEST" },
  { "platform_st", "ST" },
  { "platform_st_test", "STTEST" },
}) do
  local value = connection(item[1], item[2])
  if value then
    table.insert(connections, value)
  end
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
      connections = connections,
    },
  },
}
