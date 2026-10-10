-- nvim --headless -u NONE -l tests/sql-result-credentials.lua
-- 离线验证接收边界：只使用模拟凭据、模拟子进程和模拟流，不访问真实凭据或数据库。
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local fixture_secret = "fixture-only:/p@ss%word中文\r\n "
local marker = "__NVIM_SQL_CREDENTIAL_mock__"
local args = { "mysql", "--batch", "-h", "fixture.invalid", "-P", "3306", "-u", "fixture_user", "fixture_db" }
local fetch_mode, pending_fetch, on_fetch = "ready", nil, nil
local fetch_count, native_count, original_count = 0, 0, 0
local stream_mode, native_mode = "ok", "ok"
local stream_calls, native_calls = {}, {}
local original_system, original_wait = vim.system, vim.wait
local stream = {}

local function capture(command, sys_opts, context)
  return {
    args = vim.deepcopy(command), opts = vim.deepcopy(sys_opts),
    env_ref = sys_opts.env, context = context,
  }
end

stream.start = function(command, timeout_ms, sys_opts, context, callback)
  local call = capture(command, sys_opts, context)
  call.timeout_ms = timeout_ms
  stream_calls[#stream_calls + 1] = call
  if stream_mode == "throw" then error("synthetic spawn detail " .. fixture_secret) end
  local done, cancelled = false, 0
  local function complete(stdout, stderr, code, report)
    if done then return end
    done = true
    vim.schedule(function() callback(stdout, stderr, code, report or { kind = code == 0 and "ok" or "cancelled" }) end)
  end
  local handle = {
    cancel = function(reason)
      if done then return end
      cancelled = cancelled + 1
      complete("", reason == "timeout" and "SQL 查询超时" or "SQL 查询已取消", reason == "timeout" and 124 or 130)
    end,
    is_done = function() return done end,
  }
  call.complete, call.cancel_count = complete, function() return cancelled end
  context.cancel = handle.cancel
  if context.on_start then context.on_start(handle) end
  if stream_mode == "stderr" then
    complete("", "synthetic mysql error " .. fixture_secret, 1)
  elseif stream_mode == "truncated" then
    complete("", "error " .. fixture_secret:sub(1, 20), 1, { kind = "exit", stderr_truncated = true })
  elseif stream_mode == "limit" then
    complete("", "[SQL_RESULT_GUARD] fixture row limit", 125, { kind = "limit", stderr_truncated = true })
  elseif stream_mode == "echo" then
    complete(fixture_secret, "", 0)
  elseif stream_mode ~= "hold" then
    complete("id\n1\n", "", 0)
  end
  return handle
end
stream.run = function(command, timeout_ms, sys_opts, context)
  local result
  local handle = stream.start(command, timeout_ms, sys_opts, context, function(...)
    result = { ... }
  end)
  check(vim.wait(1000, function() return result ~= nil end, 1), "mock stream run must complete")
  check(handle.is_done(), "mock stream must finish once")
  return unpack(result)
end
package.loaded["config.sql-result-stream"] = stream
package.loaded["config.sql-credentials"] = {
  profile = function(name)
    return name == "mock" and { host = "fixture.invalid", port = "3306", user = "fixture_user" } or nil
  end,
  is_windows = function() return true end,
  environment = function(env)
    local clean = vim.deepcopy(env or {})
    clean.SAFE_FIXTURE = "1"
    return clean
  end,
  definition = function() return { name = "mock" } end,
  fetch = function(name, callback)
    check(name == "mock", "only the verified fixture profile may be fetched")
    fetch_count = fetch_count + 1
    if fetch_mode == "held" then
      pending_fetch = callback
    else
      vim.schedule(function()
        if on_fetch then on_fetch() end
        if fetch_mode == "failure" then callback(nil, "fixture credential unavailable")
        else callback(fixture_secret) end
      end)
    end
  end,
}
package.loaded["dadbod-grip.secrets"] = { expand = function(url) return url end }
local adapters = {
  run_cmd = function()
    original_count = original_count + 1
    return "original", "", 0
  end,
  run_cmd_async = function(_, _, callback)
    original_count = original_count + 1
    callback("original", "", 0)
    return function() end
  end,
}
package.loaded["dadbod-grip.adapters"] = adapters
vim.system = function(command, sys_opts, callback)
  native_count = native_count + 1
  local call = capture(command, sys_opts)
  native_calls[#native_calls + 1] = call
  if native_mode == "throw" then error("synthetic native detail " .. fixture_secret) end
  vim.schedule(function() callback({ stdout = "native\n", stderr = "", code = 0 }) end)
  return { kill = function() call.killed = true end }
end

local function options(context, password)
  return { stdin = "SELECT 1;", env = { MYSQL_PWD = password or marker }, _sql_result_guard = context }
end

local function test()
  require("config.sql-credentials.grip").install()
  local patched = adapters.run_cmd
  require("config.sql-credentials.grip").install()
  check(adapters.run_cmd == patched, "credential and result adapter installation must be idempotent")

  local context, opts = {}, nil
  opts = options(context)
  local out, err, code = adapters.run_cmd(args, 1000, opts)
  local call = stream_calls[#stream_calls]
  check(code == 0 and out == "id\n1\n" and err == "", "guarded secure query must use bounded stream")
  check(native_count == 0 and original_count == 0, "guarded secure query must not use unbounded runners")
  check(call.context == context and call.timeout_ms == 1000, "stream must receive exact request context and timeout")
  check(call.opts.clear_env == true, "secure stream must keep the clean environment")
  check(call.opts.env.MYSQL_PWD == fixture_secret, "fixture secret must reach child spawn boundary unchanged")
  check(call.opts.stdin == opts.stdin, "stream must preserve initialization and query input")
  check(call.opts._sql_result_guard == nil, "private guard context must not become a system option")
  check(call.env_ref.MYSQL_PWD == nil, "temporary child password must be cleared after stream starts")
  check(opts.env.MYSQL_PWD == marker, "caller options must keep only the opaque marker")
  check(not table.concat(call.args, " "):find(fixture_secret, 1, true), "child arguments must not contain the secret")

  stream_mode = "stderr"
  _, err, code = adapters.run_cmd(args, 1000, options({}))
  check(code == 1 and err:find("***", 1, true), "stream stderr must pass through credential redaction")
  check(not err:find(fixture_secret, 1, true), "stream stderr must not expose fixture secret")
  stream_mode = "truncated"
  _, err, code = adapters.run_cmd(args, 1000, options({}))
  check(code == 1 and not err:find(fixture_secret:sub(1, 20), 1, true),
    "truncated stderr must not expose a secret prefix that full-string redaction cannot match")
  stream_mode = "limit"
  _, err, code = adapters.run_cmd(args, 1000, options({}))
  check(code == 125 and err == "[SQL_RESULT_GUARD] fixture row limit",
    "safe result limit errors must survive even when unrelated stderr was truncated")
  stream_mode = "echo"
  out, _, code = adapters.run_cmd(args, 1000, options({}))
  check(code == 0 and out == fixture_secret, "SQL result bytes must not be rewritten by stderr redaction")
  stream_mode = "throw"
  _, err, code = adapters.run_cmd(args, 1000, options({}))
  check(code == 1 and not err:find(fixture_secret, 1, true), "stream spawn failures must hide bottom-level parameters")
  check(stream_calls[#stream_calls].env_ref.MYSQL_PWD == nil, "failed spawn must also clear temporary password")
  stream_mode = "ok"

  local before_fetch, before_stream = fetch_count, #stream_calls
  local wrong_args = vim.deepcopy(args)
  wrong_args[4] = "wrong.invalid"
  _, err, code = adapters.run_cmd(wrong_args, 1000, options({}))
  check(code ~= 0 and fetch_count == before_fetch and #stream_calls == before_stream,
    "wrong endpoint must be rejected before both credential lookup and stream spawn")
  fetch_mode = "failure"
  _, err, code = adapters.run_cmd(args, 1000, options({}))
  check(code ~= 0 and #stream_calls == before_stream, "credential failure must not start a stream")

  fetch_mode = "held"
  context = {}
  local callback_count, callback_code = 0, nil
  local cancel = adapters.run_cmd_async(args, 1000, function(_, _, status)
    callback_count, callback_code = callback_count + 1, status
  end, options(context))
  check(type(context.cancel) == "function" and pending_fetch, "request must be cancellable while waiting for credentials")
  context.cancel()
  cancel()
  pending_fetch(fixture_secret)
  check(callback_count == 1 and callback_code == 130, "pre-spawn cancellation must complete exactly once")
  check(#stream_calls == before_stream, "late credentials after cancellation must never start a client")

  fetch_mode = "ready"
  context = {}
  on_fetch = function() context.cancel() end
  out, err, code = adapters.run_cmd(args, 1000, options(context))
  on_fetch = nil
  check(code == 130 and out == "", "pre-spawn cancellation must unblock synchronous query wait")
  check(#stream_calls == before_stream, "cancelled synchronous lookup must not start a client")

  stream_mode = "hold"
  context, callback_count = {}, 0
  cancel = adapters.run_cmd_async(args, 1000, function(_, _, status)
    callback_count, callback_code = callback_count + 1, status
  end, options(context))
  check(vim.wait(1000, function() return #stream_calls > before_stream end, 1), "guarded asynchronous stream must start")
  call = stream_calls[#stream_calls]
  context.cancel()
  cancel()
  check(vim.wait(1000, function() return callback_count > 0 end, 1), "active cancellation must complete adapter callback")
  call.complete("late output", "", 0)
  check(callback_count == 1 and callback_code == 130 and call.cancel_count() == 1,
    "active cancellation and late completion must remain idempotent")

  for _, interruption in ipairs({ { reason = -2, code = 130 }, { reason = -1, code = 124 } }) do
    before_stream = #stream_calls
    local first_wait = true
    vim.wait = function(timeout, predicate, interval)
      if first_wait then
        first_wait = false
        check(original_wait(1000, function() return #stream_calls > before_stream end, 1),
          "interrupted synchronous query must first start its mock stream")
        return false, interruption.reason
      end
      return original_wait(timeout, predicate, interval)
    end
    out, err, code = adapters.run_cmd(args, 1000, options({}))
    vim.wait = original_wait
    check(code == interruption.code and out == "", "synchronous wait must distinguish cancellation and timeout")
    check(stream_calls[#stream_calls].cancel_count() == 1, "interrupted wait must collect one bounded cancellation")
  end

  stream_mode = "ok"
  before_fetch, before_stream = fetch_count, #stream_calls
  context, opts = {}, nil
  opts = options(context, "fixture-plain")
  out, err, code = adapters.run_cmd(args, 1000, opts)
  check(code == 0 and out == "id\n1\n" and #stream_calls == before_stream + 1,
    "guarded unmarked connection must use stream.run instead of original runner")
  check(fetch_count == before_fetch, "unmarked connection must not invoke credential lookup")
  call = stream_calls[#stream_calls]
  check(call.opts.env.MYSQL_PWD == "fixture-plain" and call.opts.clear_env == nil,
    "unmarked path must preserve original adapter environment semantics")
  check(call.context == context and call.opts._sql_result_guard == nil,
    "unmarked path must pass context separately from process options")
  local async_result
  cancel = adapters.run_cmd_async(args, 1000, function(stdout, _, status)
    async_result = { stdout, status }
  end, options({}, "fixture-plain"))
  check(type(cancel) == "function", "unmarked guarded async path must return a cancellation function")
  check(vim.wait(1000, function() return async_result ~= nil end, 1), "unmarked guarded async path must complete")
  check(async_result[1] == "id\n1\n" and async_result[2] == 0, "unmarked async result must be preserved")

  before_stream = #stream_calls
  out, err, code = adapters.run_cmd(args, 1000, options(nil))
  check(code == 0 and out == "native\n" and #stream_calls == before_stream and native_count == 1,
    "unguarded secure metadata and writes must retain the existing native runner")
  check(native_calls[#native_calls].opts.clear_env == true, "legacy secure path must still clear inherited environment")
  check(native_calls[#native_calls].env_ref.MYSQL_PWD == nil, "legacy native path must still clear temporary password")
  out, _, code = adapters.run_cmd(args, 1000, options(nil, "fixture-plain"))
  check(code == 0 and out == "original" and original_count == 1,
    "unguarded unmarked commands must keep the original synchronous adapter")
  adapters.run_cmd_async(args, 1000, function(stdout, _, status)
    check(stdout == "original" and status == 0, "unguarded unmarked async must preserve original callback")
  end, options(nil, "fixture-plain"))
  check(original_count == 2, "unguarded unmarked async must keep the original adapter")
end

local ok, err = xpcall(test, debug.traceback)
vim.system, vim.wait = original_system, original_wait
if not ok then error(err) end
print(("PASS: %d offline SQL result credential boundary checks"):format(checks))
