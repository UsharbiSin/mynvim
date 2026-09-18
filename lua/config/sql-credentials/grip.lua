-- 只适配本配置管理的 MySQL 连接，不改写 lazy 插件目录。
-- URL 展开得到公开标识；真实密码只在 mysql 子进程启动边界出现。
local M = {}
local credentials = require("config.sql-credentials")
local prefix = "__NVIM_SQL_CREDENTIAL_"

local function marker_name(opts)
  local value = opts and opts.env and opts.env.MYSQL_PWD
  return type(value) == "string" and value:match("^" .. prefix .. "([a-z0-9_]+)__$") or nil
end

local function validate_target(args, name)
  local profile = credentials.profile(name)
  if not profile then return nil, "SQL 连接参数不完整或凭据标识未知" end
  local executable = (args[1] or ""):gsub("\\", "/"):match("([^/]+)$") or ""
  if executable:lower() ~= "mysql" and executable:lower() ~= "mysql.exe" then
    return nil, "拒绝向非 MySQL 客户端传递 SQL 凭据"
  end
  local options = {}
  for i = 2, #args - 1 do
    if args[i] == "-h" or args[i] == "-P" or args[i] == "-u" then options[args[i]] = args[i + 1] end
  end
  if options["-h"] ~= profile.host or options["-P"] ~= profile.port or options["-u"] ~= profile.user then
    return nil, "SQL 连接目标与凭据对应的主机、端口或用户不一致；拒绝发送密码"
  end
  return profile
end

local function client_args(args)
  local result = vim.deepcopy(args)
  if not credentials.is_windows() then
    local plugin_dir = vim.env.DB_MYSQL_PLUGIN_DIR
    if not plugin_dir or plugin_dir == "" then
      local candidate = vim.fn.expand("~/.local/lib/mysql/plugin")
      if vim.uv.fs_stat(candidate .. "/mysql_native_password.so") then plugin_dir = candidate end
    end
    if plugin_dir and plugin_dir ~= "" then table.insert(result, 2, "--plugin-dir=" .. plugin_dir) end
  end
  return result
end

local function run_secure(args, timeout_ms, callback, opts, name)
  local active, process = true, nil
  local function finish(result)
    if not active then return end
    active = false
    callback(result.stdout or "", result.stderr or "", result.code or 1)
  end
  local profile, err = validate_target(args, name)
  if not profile then
    finish({ code = 1, stderr = err })
    return function() end
  end
  credentials.fetch(name, function(secret, failure)
    if not active then return end
    if not secret then finish({ code = 1, stderr = failure }); return end
    local env = credentials.environment(opts and opts.env)
    env.MYSQL_PWD = secret
    local ok, value = pcall(vim.system, client_args(args), {
      stdin = opts and opts.stdin, text = true, timeout = timeout_ms or 30000,
      env = env, clear_env = true,
    }, function(result)
      -- 错误里不能带上密码；SQL 查询结果本身不进行改写。
      if result.stderr and secret ~= "" then
        result.stderr = result.stderr:gsub(vim.pesc(secret), function() return "***" end)
      end
      secret = nil
      vim.schedule(function() finish(result) end)
    end)
    env.MYSQL_PWD = nil
    if ok then
      process = value
    else
      secret = nil
      finish({ code = 1, stderr = "MySQL 子进程启动失败（已隐藏底层参数）" })
    end
  end)
  return function()
    active = false
    if process then pcall(process.kill, process, 15) end
  end
end

function M.install()
  local secrets = require("dadbod-grip.secrets")
  local adapters = require("dadbod-grip.adapters")
  if adapters._nvim_sql_credentials then return end
  assert(type(secrets.expand) == "function" and type(adapters.run_cmd) == "function"
    and type(adapters.run_cmd_async) == "function", "Dadbod Grip 凭据适配接口已变化，请更新兼容层")
  local original_expand = secrets.expand
  local original_run, original_async = adapters.run_cmd, adapters.run_cmd_async

  secrets.expand = function(url, entry)
    if type(url) ~= "string" or not url:match("^mysql://") then return original_expand(url, entry) end
    local failure
    local tokenized = url:gsub("%$(%$?){([%w_]+)}", function(escaped, variable)
      if escaped == "$" or not variable:match("^DB_PASSWORD_") then
        return "$" .. escaped .. "{" .. variable .. "}"
      end
      local item = credentials.definition(variable:sub(#"DB_PASSWORD_" + 1))
      if not item then failure = "SQL 凭据占位符未注册"; return "" end
      return prefix .. item.name .. "__"
    end)
    if failure then return nil, failure end
    return original_expand(tokenized, entry)
  end

  adapters.run_cmd_async = function(args, timeout_ms, callback, opts)
    local name = marker_name(opts)
    if not name then return original_async(args, timeout_ms, callback, opts) end
    return run_secure(args, timeout_ms, callback, opts, name)
  end

  adapters.run_cmd = function(args, timeout_ms, opts)
    local name = marker_name(opts)
    if not name then return original_run(args, timeout_ms, opts) end
    local done, out, err, code = false, "", "", 1
    local cancel = run_secure(args, timeout_ms, function(stdout, stderr, status)
      out, err, code, done = stdout, stderr, status, true
    end, opts, name)
    if not done and not vim.wait(62000 + (timeout_ms or 30000), function() return done end, 20) then
      cancel()
      return "", "SQL 凭据读取或查询被取消/超时", 124
    end
    return out, err, code
  end
  adapters._nvim_sql_credentials = true
end

return M
