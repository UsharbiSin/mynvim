-- MySQL 查询结果的有界接收器；不读取连接配置，不改写 SQL。
-- 调用方负责把本模块限定到已授权的结果查询或 pipe 导入。
local M = {}
local budget = require("config.sql-result-budget")

M.DEFAULTS = budget.DEFAULTS

local function copy(t)
  local out = {}
  for key, value in pairs(t or {}) do out[key] = value end
  return out
end

local function limit_failure(metric, observed, maximum)
  return {
    kind = "limit", metric = metric, observed = observed, limit = maximum,
    message = budget.failure_message(metric, observed, maximum),
  }
end

-- MySQL --batch 会转义值里的 tab/newline；只数协议分隔符，不解码 UTF-8。
-- format=bytes 用于 CSV 等内容：引号中的换行不能被当作新记录。
function M.new_collector(options, format)
  local limits, err = budget.normalize_budget(options)
  if not limits then return nil, err end
  format = format or "mysql_tsv"
  if format ~= "mysql_tsv" and format ~= "bytes" then
    return nil, "[SQL_RESULT_GUARD] 不支持的结果接收格式"
  end
  local c = {
    stats = { rows = 0, columns = 0, cells = 0, bytes = 0 },
    limits = limits, retained_bytes = 0,
    _chunks = {}, _parts = {}, _blocks = {}, _part_bytes = 0, _block_bytes = 0,
    _format = format, _header = false,
    _header_columns = 0, _line_columns = 1, _line_any = false,
  }

  function c:discard()
    self._chunks, self._parts, self._blocks, self._output = {}, {}, {}, nil
    self._part_bytes, self._block_bytes, self.retained_bytes = 0, 0, 0
    self._closed = true
  end

  -- 小块只做定量合并，避免一字节输出产生数百万个表槽或反复拼接长字符串。
  function c:_flush_blocks()
    if #self._blocks == 0 then return end
    self._chunks[#self._chunks + 1] = table.concat(self._blocks)
    self._blocks, self._block_bytes = {}, 0
  end

  function c:_flush_parts()
    if #self._parts == 0 then return end
    self._blocks[#self._blocks + 1] = table.concat(self._parts)
    self._block_bytes = self._block_bytes + self._part_bytes
    self._parts, self._part_bytes = {}, 0
    if #self._blocks >= 128 or self._block_bytes >= 65536 then self:_flush_blocks() end
  end

  function c:fragment_count()
    return #self._chunks + #self._parts + #self._blocks
  end

  function c:_fail(metric, observed, maximum)
    if not self.failure then self.failure = limit_failure(metric, observed, maximum) end
    self:discard()
    return false, self.failure.message
  end

  function c:_line_end()
    if not self._header then
      self._header = true
      self._header_columns = self._line_columns
      self.stats.columns = self._line_columns
    else
      self.stats.rows = self.stats.rows + 1
      self.stats.cells = self.stats.cells + math.max(self._header_columns, self._line_columns)
      if self.stats.rows > self.limits.max_rows then
        return self:_fail("rows", self.stats.rows, self.limits.max_rows)
      end
      if self.stats.cells > self.limits.max_cells then
        return self:_fail("cells", self.stats.cells, self.limits.max_cells)
      end
    end
    self._line_columns, self._line_any = 1, false
    return true
  end

  function c:feed(chunk)
    if self._closed then return false, self.failure and self.failure.message end
    if chunk == nil or chunk == "" then return true end
    assert(type(chunk) == "string", "collector expects a byte string")
    self.stats.bytes = self.stats.bytes + #chunk
    if self.stats.bytes > self.limits.max_bytes then
      return self:_fail("bytes", self.stats.bytes, self.limits.max_bytes)
    end

    if self._format == "mysql_tsv" then
      local cursor = 1
      while cursor <= #chunk do
        local pos = chunk:find("[\t\n]", cursor)
        if not pos then
          self._line_any = true
          break
        end
        if pos > cursor then self._line_any = true end
        if chunk:byte(pos) == 9 then
          self._line_any = true
          self._line_columns = self._line_columns + 1
          self.stats.columns = math.max(self.stats.columns, self._line_columns)
          if self._line_columns > self.limits.max_columns then
            return self:_fail("columns", self._line_columns, self.limits.max_columns)
          end
        else
          local ok, line_err = self:_line_end()
          if not ok then return false, line_err end
        end
        cursor = pos + 1
      end
    end

    self._parts[#self._parts + 1] = chunk
    self._part_bytes = self._part_bytes + #chunk
    if #self._parts >= 128 or self._part_bytes >= 65536 then self:_flush_parts() end
    self.retained_bytes = self.retained_bytes + #chunk
    return true
  end

  function c:finish()
    if self.failure then return nil, self.failure.message end
    if self._closed then return self._output end
    if self._format == "mysql_tsv" and self._line_any then
      local ok, line_err = self:_line_end()
      if not ok then return nil, line_err end
    end
    self:_flush_parts()
    self:_flush_blocks()
    self._output = table.concat(self._chunks)
    self._chunks, self._closed = {}, true
    return self._output
  end

  return c
end

-- 保留 --defaults-file 等必须位于最前面的选项，且不原地修改 argv。
function M.prepare_args(args, format)
  local out = {}
  for index, value in ipairs(args) do out[index] = value end
  local executable = (out[1] or ""):gsub("\\", "/"):match("([^/]+)$") or ""
  executable = executable:lower()
  if format == "bytes" or not (executable == "mysql" or executable == "mysql.exe"
      or executable == "mariadb" or executable == "mariadb.exe") then return out end
  local value_options = {
    ["--defaults-file"] = true, ["--defaults-extra-file"] = true,
    ["--defaults-group-suffix"] = true, ["--login-path"] = true,
  }
  local argument_values = copy(value_options)
  for _, option in ipairs({
    "-h", "-P", "-u", "-D", "-S", "-e", "--host", "--port", "--user", "--database",
    "--socket", "--execute", "--protocol", "--plugin-dir", "--default-auth",
    "--default-character-set", "--character-sets-dir", "--init-command", "--connect-timeout",
    "--max-allowed-packet", "--net-buffer-length", "--ssl-mode", "--ssl-ca", "--ssl-capath",
    "--ssl-cert", "--ssl-key", "--ssl-cipher", "--tls-version", "--tls-ciphersuites",
    "--server-public-key-path", "--bind-address", "--histignore", "--tee",
  }) do argument_values[option] = true end
  -- 只规范 quick 本身，保留带值选项的用户名/路径/SQL 与 -- 后的数据库名。
  local filtered, index = { out[1] }, 2
  while index <= #out do
    local arg = out[index]
    if arg == "--" then
      for rest = index, #out do filtered[#filtered + 1] = out[rest] end
      break
    elseif argument_values[arg] and out[index + 1] then
      filtered[#filtered + 1], filtered[#filtered + 2] = arg, out[index + 1]
      index = index + 2
    else
      if arg ~= "--quick" and arg ~= "-q" and arg ~= "--skip-quick"
          and arg ~= "--disable-quick" and arg ~= "--enable-quick"
          and not arg:match("^%-%-quick=") then
        filtered[#filtered + 1] = arg
      end
      index = index + 1
    end
  end
  out = filtered

  local first = 2
  while out[first] do
    local arg = out[first]
    local key = arg:match("^([^=]+)=")
    if value_options[arg] then
      first = first + 2
    elseif (key and value_options[key]) or arg == "--no-defaults"
        or arg == "--print-defaults" then
      first = first + 1
    else
      break
    end
  end
  table.insert(out, math.min(first, #out + 1), "--quick")
  return out
end

local function close_timer(timer)
  if not timer then return end
  pcall(function()
    if not timer:is_closing() then timer:stop(); timer:close() end
  end)
end

local function delay_ms(value, fallback)
  return type(value) == "number" and value >= 1 and value < 2147483647
    and math.floor(value) or fallback
end

local function failure(kind, message)
  local prefix = "[SQL_RESULT_GUARD] "
  return { kind = kind, message = message:sub(1, #prefix) == prefix and message or prefix .. message }
end

-- callback(stdout, stderr, code, report) 在主循环交付，恰好一次。
-- handle.cancel() 可在 on_start 中调用；此时不会创建子进程。
-- sys_opts 由现有凭据边界提供，env/clear_env/stdin 原样传给 vim.system。
function M.start(args, timeout_ms, sys_opts, context, callback)
  context = context or {}
  callback = callback or function() end
  local collector, config_err = M.new_collector(context.budget, context.format)
  local timeout = delay_ms(timeout_ms, 30000)
  local kill_grace = delay_ms(context.kill_grace_ms, 250)
  local exit_grace = delay_ms(context.exit_grace_ms, 1000)
  local limits = collector and collector.limits
  local own_group = context.format == "bytes" and vim.fn.has("win32") == 0
  local on_finish, on_start = context.on_finish, context.on_start
  local state = {
    done = false, stopping = false, spawning = false, process = nil,
    stderr_chunks = {}, stderr_bytes = 0, stderr_received = 0,
  }
  local handle = {}
  local finish, stop

  function handle.is_done() return state.done end

  local function stderr_text()
    local value = table.concat(state.stderr_chunks)
    state.stderr_chunks = {}
    return value
  end

  local function arm(field, ms, fn)
    close_timer(state[field])
    local timer = vim.uv.new_timer()
    state[field] = timer
    timer:start(ms, 0, function()
      close_timer(timer)
      if state[field] == timer then state[field] = nil end
      if not state.done then fn() end
    end)
  end

  local function signal(name)
    if state.group_pid then
      -- 只向本次 detach=true 新建的进程组发信号；绝不使用调用方所在组。
      pcall(vim.uv.kill, -state.group_pid, name)
    elseif state.process then
      pcall(state.process.kill, state.process, name)
    end
  end

  local function terminate()
    if state.done or not state.process or state.termination_started then return end
    state.termination_started = true
    signal("sigterm")
    arm("kill_timer", kill_grace, function()
      signal("sigkill")
      arm("exit_timer", exit_grace, function()
        -- OS 尚未确认退出也不能令编辑器永久等待；迟到输出将被丢弃。
        finish({ code = 1, signal = 9 }, true)
      end)
    end)
  end

  stop = function(reason)
    if state.done or state.stopping then return false end
    state.stopping, state.failure = true, reason
    if collector then collector:discard() end
    close_timer(state.timeout_timer)
    state.timeout_timer = nil
    if state.process then
      terminate()
    elseif not state.spawning then
      finish({ code = 1, signal = 0 })
    end
    return true
  end

  function handle.cancel(reason)
    local why = reason == "timeout"
      and failure("timeout", "查询超时，已停止本地结果读取")
      or failure("cancelled", "查询已取消，已停止本地结果读取")
    return stop(why)
  end

  finish = function(result, exit_unconfirmed)
    if state.done then return end
    local stdout = ""
    if not state.failure and collector then
      local value, parse_err = collector:finish()
      if not value then
        state.failure = collector.failure or failure("read", parse_err or "结果接收失败")
      else
        stdout = value
      end
    end
    local report = copy(state.failure or { kind = "exit" })
    report.stats = collector and copy(collector.stats)
      or { rows = 0, columns = 0, cells = 0, bytes = 0 }
    report.signal = result and result.signal or 0
    report.stderr_bytes = state.stderr_received
    report.stderr_retained_bytes = state.stderr_bytes
    report.stderr_truncated = state.stderr_received > state.stderr_bytes
    report.exit_unconfirmed = exit_unconfirmed == true
    local code = result and result.code or 1
    local stderr = stderr_text()
    if state.failure then
      stdout = ""
      if report.kind == "limit" then code = 125
      elseif report.kind == "timeout" then code = 124
      elseif report.kind == "cancelled" then code = 130
      else code = 1 end
      stderr = report.message
    elseif code ~= 0 or report.signal ~= 0 then
      -- 命令失败或被信号中断时，部分 stdout 不得进入正常结果解析。
      stdout = ""
      if code == 0 then code = 1 end
    end

    state.done, state.process = true, nil
    close_timer(state.timeout_timer)
    close_timer(state.kill_timer)
    close_timer(state.exit_timer)
    state.timeout_timer, state.kill_timer, state.exit_timer = nil, nil, nil
    if collector then collector:discard() end
    if context.cancel == handle.cancel then context.cancel = nil end
    report.code = code
    handle.report = report
    vim.schedule(function()
      if type(on_finish) == "function" then pcall(on_finish, report) end
      callback(stdout, stderr, code, report)
    end)
  end

  context.cancel = handle.cancel
  if not collector then
    stop(failure("config", config_err or "结果额度配置无效"))
    return handle
  end
  if type(on_start) == "function" then
    local ok = pcall(on_start, handle)
    if not ok then
      stop(failure("callback", "无法初始化结果接收状态"))
    end
  end
  if state.done or state.stopping then return handle end

  local options = copy(sys_opts)
  options._sql_result_guard = nil
  -- 用原始字节计数；UTF-8 和 CRLF 均不能在分块时被重写。
  options.text, options.timeout = false, nil
  -- Unix pipe 命令的 shell 与 producer 必须一起停止，否则继承的 stdout 不会 EOF。
  -- vim.system 的 detach 会新建进程组；不调用 unref，仍等待并清理本次进程。
  if own_group then options.detach = true end
  options.stdout = function(err, chunk)
    if state.done or state.stopping then return end
    if err then
      stop(failure("read", "读取数据库客户端输出失败"))
      return
    end
    if chunk then
      local ok = collector:feed(chunk)
      if not ok then stop(collector.failure) end
    end
  end
  options.stderr = function(err, chunk)
    if state.done then return end
    if err then
      stop(failure("read", "读取数据库客户端错误输出失败"))
      return
    end
    if not chunk then return end
    state.stderr_received = state.stderr_received + #chunk
    local keep = math.min(#chunk, math.max(0, limits.max_stderr_bytes - state.stderr_bytes))
    if keep > 0 then
      state.stderr_chunks[#state.stderr_chunks + 1] = chunk:sub(1, keep)
      state.stderr_bytes = state.stderr_bytes + keep
    end
  end

  state.spawning = true
  local ok, process = pcall(vim.system, M.prepare_args(args, context.format), options, function(result)
    finish(result)
  end)
  state.spawning = false
  if not ok then
    -- 底层异常可能含 argv/env；不给调用方或日志传递该异常文本。
    if state.stopping then
      finish({ code = 1, signal = 0 })
    else
      stop(failure("spawn", "无法启动数据库客户端或导入命令"))
    end
    return handle
  end
  if state.done then return handle end
  state.process, handle.pid = process, process.pid
  if own_group and type(process.pid) == "number" and process.pid > 1
      and process.pid ~= vim.uv.os_getpid() then
    state.group_pid = process.pid
  end
  if state.stopping then
    terminate()
  else
    arm("timeout_timer", timeout, function()
      stop(failure("timeout", "查询超时，已停止本地结果读取"))
    end)
  end
  return handle
end

function M.run(args, timeout_ms, sys_opts, context)
  context = context or {}
  local outcome
  local accepting = true
  local handle = M.start(args, timeout_ms, sys_opts, context, function(...)
    if accepting then outcome = { ... } end
  end)
  local timeout = delay_ms(timeout_ms, 30000)
  local stop_wait = delay_ms(context.kill_grace_ms, 250)
    + delay_ms(context.exit_grace_ms, 1000) + 1000
  local ok, completed, reason = pcall(vim.wait, timeout + stop_wait,
    function() return outcome ~= nil end, 10)
  if not outcome then
    handle.cancel((ok and reason ~= -2 and not completed) and "timeout" or nil)
    -- Ctrl-C 只取消本次请求，随后继续泵事件直到子进程退出/有界清理完成。
    pcall(vim.wait, stop_wait, function() return outcome ~= nil end, 10)
  end
  if outcome then return unpack(outcome, 1, 4) end
  -- 连续 Ctrl-C 可中断清理等待；私有停止定时器仍继续，迟到数据不再交付。
  accepting = false
  handle.cancel()
  return "", "[SQL_RESULT_GUARD] 结果接收已停止，客户端退出尚未确认", 130, {
    kind = "cancelled", stats = { rows = 0, columns = 0, cells = 0, bytes = 0 },
    exit_unconfirmed = true, code = 130,
  }
end

return M
