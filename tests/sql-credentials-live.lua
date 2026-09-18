-- Optional: NVIM_SQL_CREDENTIAL_LIVE=1 nvim --headless -u NONE -l tests/sql-credentials-live.lua
-- Only SELECT 1 and SQLS configuration inspection; never prints connection values.
if vim.env.NVIM_SQL_CREDENTIAL_LIVE ~= "1" then
  print("SKIP: live SQL credential tests require explicit opt-in")
  return
end
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/dadbod-grip.nvim")
local credentials = require("config.sql-credentials")
credentials.setup()
require("config.dadbod-grip")
local adapters = require("dadbod-grip.adapters")
local old_timeout = adapters.configured_timeout
adapters.configured_timeout = function() return 10000 end
local client
local function test()
  local connections = credentials.connections()
  assert(#connections > 0, "No configured profiles for live test")
  for _, connection in ipairs(connections) do
    local result = require("dadbod-grip.db").query("SELECT 1 AS credential_check;", connection.url)
    assert(result and result.rows and result.rows[1] and tostring(result.rows[1][1]) == "1",
      "Live MySQL SELECT 1 failed for " .. connection.name)
    print("PASS: live MySQL credential query / " .. connection.name)
  end
  local executable = vim.fn.exepath("sqls")
  if executable == "" then
    executable = vim.fn.stdpath("data") .. "/mason/packages/sqls/sqls" .. (credentials.is_windows() and ".exe" or "")
  end
  assert(vim.fn.executable(executable) == 1, "SQLS binary unavailable for live test")
  local configured = false
  local id = vim.lsp.start({
    name = "sqls-credential-test", cmd = { executable }, root_dir = vim.fn.getcwd(),
    settings = { sqls = { connections = {} } },
    on_init = function(c)
      client = c
      local original_notify = c.notify
      c.notify = function(self, method, params)
        local sent = original_notify(self, method, params)
        if method == "workspace/didChangeConfiguration" and #params.settings.sqls.connections > 0 then
          configured = sent
        end
        return sent
      end
      require("config.sql-credentials.sqls").on_init(c)
    end,
  })
  assert(id and vim.wait(30000, function() return configured end, 25), "SQLS credential notification not sent")
  local response = client:request_sync("workspace/executeCommand", { command = "showConnections", arguments = {} }, 30000)
  assert(response and not response.err, "SQLS showConnections request failed")
  local names = vim.inspect(response.result)
  for _, connection in ipairs(connections) do
    assert(names:find(connection.name, 1, true), "SQLS did not apply credential profile " .. connection.name)
  end
  assert(#client.settings.sqls.connections == 0, "Live client must not retain secret settings")
  print("PASS: live SQLS runtime configuration / " .. #connections .. " profiles")
  local databases = client:request_sync("workspace/executeCommand", { command = "showDatabases", arguments = {} }, 30000)
  assert(databases and not databases.err and databases.result, "SQLS live metadata query failed")
  print("PASS: live SQLS metadata query")
end
local ok, err = xpcall(test, debug.traceback)
adapters.configured_timeout = old_timeout
if client then client:stop(true) end
if not ok then error(err) end
print("PASS: live credential integration")
