-- SQLS 通过运行时通知接收凭据；共享 LSP 配置始终不含真实密码。
local M = {}
local credentials = require("config.sql-credentials")

local function escape_path(value)
  return (value:gsub("([^%w%-%._~])", function(c) return ("%%%02X"):format(c:byte()) end))
end

function M.dsn(profile, password)
  local host = profile.host
  if host:find(":", 1, true) and not host:match("^%[") then host = "[" .. host .. "]" end
  return ("%s:%s@tcp(%s:%s)/%s"):format(profile.user, password, host, profile.port,
    escape_path(profile.database))
end

function M.configure(client)
  client._sql_credential_generation = (client._sql_credential_generation or 0) + 1
  local generation = client._sql_credential_generation
  local profiles, connections, failures = credentials.profiles(), {}, {}
  local function current()
    return client._sql_credential_generation == generation and not client:is_stopped()
  end
  local function send()
    if not current() then return end
    -- rpc.notify 同步序列化并记录发送数据。只在这次同步调用期间关闭日志，
    -- 随即恢复，不更改用户的全局调试设置，也不隐藏后续服务器错误。
    local level = vim.lsp.log.get_level()
    vim.lsp.log.set_level("OFF")
    local ok, sent = pcall(client.notify, client, "workspace/didChangeConfiguration", {
      settings = { sqls = { connections = connections } },
    })
    vim.lsp.log.set_level(level)
    -- 不把 DSN 放回 client.settings/config、vim.g、buffer 或任何持久化文件。
    connections = nil
    if not ok or not sent then
      vim.notify("SQLS 凭据配置发送失败", vim.log.levels.ERROR)
    elseif #failures > 0 then
      vim.notify("SQLS 未加载凭据：" .. table.concat(failures, "、")
        .. "。请检查钥匙环，然后执行 :SqlCredentialsReload", vim.log.levels.WARN)
    end
  end
  local function next_profile(index)
    if not current() then return end
    local profile = profiles[index]
    if not profile then send(); return end
    credentials.fetch(profile.name, function(password)
      if not current() then return end
      if password then
        connections[#connections + 1] = {
          alias = profile.name, driver = "mysql", dataSourceName = M.dsn(profile, password),
        }
      else
        failures[#failures + 1] = profile.name
      end
      next_profile(index + 1)
    end)
  end
  next_profile(1)
end

function M.on_init(client)
  -- 等 initialized 与默认空配置通知发送完成，再异步获取凭据。
  vim.schedule(function() if not client:is_stopped() then M.configure(client) end end)
end

return M
