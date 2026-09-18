-- 共用凭据接口。只在使用 SQL 时取密，不缓存密码、不向全局环境写回密码。
local M = {}
local definitions = {
  { name = "tongyan", suffix = "TY" },
  { name = "tongyan_test", suffix = "TYTEST" },
  { name = "platform_st", suffix = "ST" },
  { name = "platform_st_test", suffix = "STTEST" },
}
local timeout = 60000
local pending = {}
local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))

function M.is_windows()
  if vim.g.is_win ~= nil then return vim.g.is_win == 1 end
  return vim.fn.has("win32") == 1
end

function M.definition(name)
  for _, item in ipairs(definitions) do
    if item.name == name or item.suffix == name then return vim.deepcopy(item) end
  end
end

function M.profile(name)
  local item = M.definition(name)
  if not item then return nil end
  for _, field in ipairs({ "USER", "HOST", "PORT", "NAME" }) do
    local value = vim.env["DB_" .. field .. "_" .. item.suffix]
    if not value or value == "" then return nil end
    item[field == "NAME" and "database" or field:lower()] = value
  end
  return item
end

function M.profiles()
  local result = {}
  for _, item in ipairs(definitions) do
    local profile = M.profile(item.name)
    if profile then result[#result + 1] = profile end
  end
  return result
end

function M.connections()
  local result = {}
  for _, item in ipairs(M.profiles()) do
    local suffix = item.suffix
    result[#result + 1] = {
      name = item.name,
      -- 保留旧模板，已有 buffer、保存的查询和连接不需要重写。
      url = ("mysql://${DB_USER_%s}:${DB_PASSWORD_%s}@${DB_HOST_%s}:${DB_PORT_%s}/${DB_NAME_%s}")
        :format(suffix, suffix, suffix, suffix, suffix),
    }
  end
  return result
end

function M.environment(extra)
  local result = {}
  for name, value in pairs(vim.fn.environ()) do
    local upper = name:upper()
    if not upper:match("^DB_PASSWORD_") and upper ~= "MYSQL_PWD" then result[name] = value end
  end
  for name, value in pairs(extra or {}) do
    local upper = name:upper()
    if not upper:match("^DB_PASSWORD_") and upper ~= "MYSQL_PWD" then result[name] = value end
  end
  return result
end

function M.helper_command(action, name)
  local candidates = M.is_windows() and { "python", "python3" } or { "python3", "python" }
  for _, executable in ipairs(candidates) do
    local python = vim.fn.exepath(executable)
    if python ~= "" then
      -- -I/-S 禁止项目目录、PYTHONPATH 和 sitecustomize 介入凭据助手。
      return { python, "-I", "-S", "-B", "-X", "utf8",
        vim.fs.joinpath(root, "scripts", "sql_credentials.py"), action, name }
    end
  end
  return nil, "未找到 Python 3，无法运行 SQL 凭据助手"
end

function M.fetch(name, callback)
  local item = M.definition(name)
  if not item then callback(nil, "未知的 SQL 凭据名称"); return end
  name = item.name
  if pending[name] then
    table.insert(pending[name], callback)
    return
  end
  pending[name] = { callback }
  local function finish(secret, err)
    local callbacks = pending[name]
    pending[name] = nil
    for _, cb in ipairs(callbacks or {}) do cb(secret, err) end
  end
  local backend = require("config.sql-credentials." .. (M.is_windows() and "windows" or "secret-service"))
  local command, err = backend.command(name)
  if not command then finish(nil, err); return end
  local ok = pcall(vim.system, command, {
    -- 二进制读取：不 trim、不转换 CRLF，保留密码末尾空格和换行。
    text = false, timeout = timeout, clear_env = true, env = M.environment(),
  }, function(result)
    local secret = result.stdout
    local valid = result.code == 0 and type(secret) == "string"
      and secret ~= "" and not secret:find("\0", 1, true)
    result.stdout, result.stderr = nil, nil
    vim.schedule(function()
      if valid then
        finish(secret)
      else
        finish(nil, "SQL 凭据 " .. name .. " 读取失败：检查凭据是否存在、钥匙环解锁状态及超时")
      end
      secret = nil
    end)
  end)
  if not ok then finish(nil, "SQL 凭据助手启动失败；未使用旧环境变量回退") end
end

-- Grip 的同步接口需要等待；vim.wait 会泵送事件，图形解锁和界面仍可响应。
function M.get(name)
  local done, abandoned = false, false
  local secret, err
  M.fetch(name, function(value, failure)
    if abandoned then return end
    secret, err, done = value, failure, true
  end)
  if not done and not vim.wait(timeout + 2000, function() return done end, 20) then
    abandoned = true
    return nil, "SQL 凭据读取被取消或超时"
  end
  return secret, err
end

function M.setup()
  if M._configured then return end
  M._configured = true
  -- 在插件和它们的子进程启动前移除继承的旧密码，不保留一份 Lua 副本。
  for name in pairs(vim.fn.environ()) do
    local upper = name:upper()
    if upper:match("^DB_PASSWORD_") or upper == "MYSQL_PWD" then vim.env[name] = nil end
  end
  vim.api.nvim_create_user_command("SqlCredentialsCheck", function(opts)
    local names = opts.args ~= "" and { opts.args } or vim.tbl_map(function(p) return p.name end, M.profiles())
    if #names == 0 then vim.notify("没有配置完整的 SQL 普通连接参数"); return end
    for _, name in ipairs(names) do
      M.fetch(name, function(secret, err)
        vim.notify(secret and (name .. "：凭据可用") or err,
          secret and vim.log.levels.INFO or vim.log.levels.ERROR)
      end)
    end
  end, { nargs = "?", complete = function() return vim.tbl_map(function(p) return p.name end, definitions) end })
  vim.api.nvim_create_user_command("SqlCredentialsReload", function()
    for _, client in ipairs(vim.lsp.get_clients({ name = "sqls" })) do
      require("config.sql-credentials.sqls").configure(client)
    end
    vim.notify("SQLS 凭据已请求重新加载；Grip 会在下一次调用时重新取密")
  end, {})
end

return M
