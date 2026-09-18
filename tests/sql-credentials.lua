-- nvim --headless -u NONE -l tests/sql-credentials.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/dadbod-grip.nvim")
local checks = 0
local function check(value, message) assert(value, message); checks = checks + 1 end
local credentials = require("config.sql-credentials")
local original_system, original_exepath = vim.system, vim.fn.exepath
local original_notify, original_fetch = vim.notify, credentials.fetch
local saved_env = vim.fn.environ()
local notices, calls = {}, {}
local password = "  fictitious:/p@ss%word${TOKEN}中文\r\n "
local helper_failure, mysql_failure = false, false
local function fake_system(args, opts, callback)
  calls[#calls + 1] = { args = vim.deepcopy(args), opts = vim.deepcopy(opts) }
  local mysql = args[1] == "mysql"
  if mysql then
    check(opts.clear_env == true, "mysql must receive an explicit clean environment")
    check(opts.env.MYSQL_PWD == password, "password must reach only the target child unchanged")
    check(opts.env.DB_PASSWORD_ST == nil, "legacy passwords must not reach mysql")
    check(not table.concat(args, " "):find(password, 1, true), "argv must never contain password")
  else
    check(opts.clear_env == true and opts.env.MYSQL_PWD == nil, "credential helper env must be clean")
    check(opts.text == false, "credential stdout must use binary mode")
  end
  local result = mysql
    and { code = mysql_failure and 1 or 0, stdout = "id\n1\n", stderr = mysql_failure and ("error " .. password) or "" }
    or { code = helper_failure and 1 or 0, stdout = helper_failure and "" or password, stderr = "sensitive backend detail" }
  vim.schedule(function() callback(result) end)
  return { kill = function() end }
end

local function test()
  vim.notify = function(message) notices[#notices + 1] = message end
  for name in pairs(saved_env) do if name:match("^DB_") then vim.env[name] = nil end end
  vim.env.DB_USER_ST, vim.env.DB_HOST_ST = "test_user", "127.0.0.1"
  vim.env.DB_PORT_ST, vim.env.DB_NAME_ST = "3306", "sample_db"
  vim.env.DB_PASSWORD_ST, vim.env.MYSQL_PWD = "old-fake-password", "old-fake-password"
  credentials.setup()
  check(vim.env.DB_PASSWORD_ST == nil and vim.env.MYSQL_PWD == nil, "startup must scrub inherited passwords")
  check(vim.env.DB_USER_ST == "test_user", "startup must retain non-secret parameters")
  local connections = credentials.connections()
  check(#connections == 1 and connections[1].name == "platform_st", "connection alias must not become database name")
  check(connections[1].url:find("${DB_PASSWORD_ST}", 1, true), "connections must keep legacy-compatible placeholders")
  check(#require("config.sql-runner").connections() == 1, "runner must not require a password env variable")
  local profile = credentials.profile("platform_st")
  check(profile.database == "sample_db", "database and alias must remain separate")

  vim.system = fake_system
  vim.fn.exepath = function(name)
    if name == "secret-tool" then return "/usr/bin/secret-tool" end
    return original_exepath(name)
  end
  vim.g.is_win = 0
  local before = #calls
  local secret, err = credentials.get("platform_st")
  check(secret == password and not err, "Secret Service must preserve whitespace, CRLF and UTF-8")
  check(calls[before + 1].args[2] == "lookup", "Arch backend must use lookup")
  vim.g.is_win = 1
  secret, err = credentials.get("platform_st")
  check(secret == password and not err, "Windows helper output must preserve bytes")
  check(vim.tbl_contains(calls[#calls].args, "-I") and vim.tbl_contains(calls[#calls].args, "-S"), "Python helper must be isolated")
  helper_failure = true
  vim.env.DB_PASSWORD_ST = "old-fake-password"
  secret, err = credentials.get("platform_st")
  check(secret == nil and err and not err:find("sensitive backend detail", 1, true), "no environment fallback or raw stderr on failure")
  helper_failure = false

  local secrets = require("dadbod-grip.secrets")
  local adapters = require("dadbod-grip.adapters")
  require("config.sql-credentials.grip").install()
  local patched = adapters.run_cmd
  require("config.sql-credentials.grip").install()
  check(adapters.run_cmd == patched, "installation must be idempotent")
  local expanded = assert(secrets.expand(connections[1].url))
  check(not expanded:find(password, 1, true) and not expanded:find("old-fake-password", 1, true), "expanded URL must contain no real password")
  check(expanded:find("__NVIM_SQL_CREDENTIAL_platform_st__", 1, true), "only opaque reference reaches URL parser")
  local parsed = require("dadbod-grip.sql").parse_dadbod_url(expanded, "3306")
  local args = { "mysql", "--batch", "-h", parsed.host, "-P", parsed.port, "-u", parsed.user, parsed.dbname }
  local opts = { stdin = "SELECT 1;", env = { MYSQL_PWD = parsed.pass } }
  local out, failure, code = adapters.run_cmd(args, 1000, opts)
  check(code == 0 and out == "id\n1\n" and failure == "", "synchronous adapter must preserve result")
  check(opts.env.MYSQL_PWD == parsed.pass, "caller options must remain secret-free")
  local done = false
  adapters.run_cmd_async(args, 1000, function(_, _, status) done = status == 0 end, opts)
  check(vim.wait(2000, function() return done end, 10), "asynchronous adapter must call back")
  mysql_failure = true
  _, failure, code = adapters.run_cmd(args, 1000, opts)
  check(code == 1 and not failure:find(password, 1, true), "MySQL error must redact password")
  mysql_failure = false
  local count = #calls
  local wrong_target = vim.deepcopy(args); wrong_target[4] = "untrusted.example"
  _, failure, code = adapters.run_cmd(wrong_target, 1000, opts)
  check(code ~= 0 and #calls == count, "endpoint mismatch must fail before credential lookup")
  helper_failure = true
  _, failure, code = adapters.run_cmd(args, 1000, opts)
  check(code ~= 0 and calls[#calls].args[1] ~= "mysql", "missing credential must not start mysql")
  helper_failure = false
  vim.g.is_win = 0; vim.env.DB_MYSQL_PLUGIN_DIR = "/home/test/plugin dir"
  adapters.run_cmd(args, 1000, opts)
  check(calls[#calls].args[2] == "--plugin-dir=/home/test/plugin dir", "Arch plugin directory must stay one argv item")

  local sqls = dofile("lsp/sqls.lua")
  check(#sqls.settings.sqls.connections == 0, "static LSP config must contain no live DSN")
  local received
  local client = {
    settings = sqls.settings, config = { settings = sqls.settings },
    is_stopped = function() return false end,
    notify = function(_, method, payload)
      check(vim.lsp.log.get_level() == vim.log.levels.OFF, "sensitive RPC must not enter debug log")
      check(method == "workspace/didChangeConfiguration", "SQLS configuration method")
      received = vim.deepcopy(payload)
      return true
    end,
  }
  local old_level = vim.lsp.log.get_level()
  vim.lsp.log.set_level("DEBUG")
  require("config.sql-credentials.sqls").configure(client)
  check(vim.wait(2000, function() return received ~= nil end, 10), "SQLS must receive asynchronous configuration")
  check(received.settings.sqls.connections[1].dataSourceName:find(password, 1, true), "SQLS runtime DSN must receive the password")
  check(#client.settings.sqls.connections == 0 and #client.config.settings.sqls.connections == 0, "SQLS config must not retain credentials")
  check(vim.lsp.log.get_level() == vim.log.levels.DEBUG, "RPC send must restore logging level")
  vim.lsp.log.set_level(old_level)
  check(not table.concat(notices, "\n"):find(password, 1, true), "notifications must not expose secrets")
end

local ok, err = xpcall(test, debug.traceback)
vim.system, vim.fn.exepath, vim.notify, credentials.fetch = original_system, original_exepath, original_notify, original_fetch
for name in pairs(vim.fn.environ()) do if name:match("^DB_") or name == "MYSQL_PWD" then vim.env[name] = nil end end
for name, value in pairs(saved_env) do vim.env[name] = value end
if not ok then error(err) end
print(("PASS: %d cross-platform SQL credential checks"):format(checks))
