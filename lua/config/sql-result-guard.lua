-- SQL 结果保护：在接收、复制和渲染之前拒绝超限结果；不修改用户 SQL。
local M = {}
local budget = require("config.sql-result-budget")
local PREFIX = "[SQL_RESULT_GUARD] "
local installed, limits = false, nil
local current, foreground, pending_mysql
local serial = 0
local active = {}
local result_owner = setmetatable({}, { __mode = "k" })
local state_owner = setmetatable({}, { __mode = "k" })
local snapshots = setmetatable({}, { __mode = "k" })

local function pack(...) return { n = select("#", ...), ... } end

local function message(err)
  return tostring(err):match("%[SQL_RESULT_GUARD%] ([^\n]*)")
end

local function abort(reason)
  error(PREFIX .. (message(reason) or reason), 0)
end

local function check_live(op)
  if op and op.cancelled then abort(op.cancelled) end
end

local fields = {
  "state", "query_spec", "query_sql", "total_rows", "elapsed_ms", "last_action",
  "_render", "_undo_stack", "_redo_stack",
}

local function snapshot(session)
  if not session then return nil end
  local saved = {}
  for _, key in ipairs(fields) do saved[key] = session[key] end
  -- 页面/排序会原地修改；数据和 undo 栈只保存引用，不再复制整份结果。
  saved.query_spec = session.query_spec and vim.deepcopy(session.query_spec) or nil
  return saved
end

local function restore(session, saved)
  if not session or not saved then return end
  for _, key in ipairs(fields) do session[key] = saved[key] end
end

local function cancel_operation(op, reason)
  if not op or op.finished or op.cancelled then return false end
  op.cancelled = reason or "已取消本次结果接收；未显示不完整结果"
  for context in pairs(op.contexts) do
    if context.cancel then context.cancel() end
  end
  return true
end

local function target(view, bufnr, opts)
  local win = opts and opts.reuse_win
  if not win and view.find_content_win then win = view.find_content_win() end
  if not bufnr and win and vim.api.nvim_win_is_valid(win) then
    bufnr = vim.api.nvim_win_get_buf(win)
  end
  return bufnr, win
end

local function operation(callback, args, options)
  if not installed then return callback(unpack(args, 1, args.n)) end
  options = options or {}
  local view = require("dadbod-grip.view")
  local bufnr, win = target(view, options.bufnr, options.opts)
  local session = bufnr and view._sessions[bufnr] or nil
  serial = serial + 1
  local op = {
    id = serial, contexts = {}, target_buf = bufnr, target_win = win,
    source_buf = vim.api.nvim_get_current_buf(),
    source_win = vim.api.nvim_get_current_win(),
    handoff = options.handoff, refresh_handoff = options.refresh_handoff,
    session = session,
    before = snapshot(session),
  }
  if foreground and not foreground.finished then
    cancel_operation(foreground, "新查询已取代本次查询；已丢弃旧查询结果")
  end
  local previous = current
  current, foreground = op, op
  active[op] = true
  local result = pack(pcall(callback, unpack(args, 1, args.n)))
  current = previous
  op.finished = true
  active[op] = nil
  if foreground == op then foreground = nil end
  for context in pairs(op.contexts) do
    if context.cancel then context.cancel() end
  end
  op.contexts = {}

  local failed = op.cancelled or op.failure or not result[1] or result[2] == false
  if session and view._sessions[bufnr] == session then
    local committed = snapshots[session]
    if committed and committed.id > op.id then
      -- 老调用的分页包装可能在退出时回滚元数据，恢复最后一次成功发布的版本。
      restore(session, committed.value)
    elseif failed then
      restore(session, op.before)
    else
      snapshots[session] = { id = op.id, value = snapshot(session) }
    end
  end
  if op.published_buf then
    local published = view._sessions[op.published_buf]
    if published and not failed then
      snapshots[published] = { id = op.id, value = snapshot(published) }
    end
  end

  -- token 可能与当前结果同寿命；释放旧结果/会话引用，避免串起查询历史。
  op.before, op.session, op.handoff = nil, nil, nil
  local guard_error = op.cancelled or (not result[1] and message(result[2]))
    or (result[2] == false and message(result[3]))
  if guard_error then
    if options.return_error then return false, guard_error end
    -- 被新查询取代的旧调用静默退出；新查询的界面和提示归新调用所有。
    if not op.superseded and not (op.cancelled and op.cancelled:find("新查询", 1, true)) then
      vim.notify("SQL 结果保护：" .. guard_error, vim.log.levels.WARN)
    end
    return nil
  end
  if not result[1] then error(result[2], 0) end
  return unpack(result, 2, result.n)
end

-- sql-runner 的完整查询作用域，也覆盖 SHOW PROCESSLIST 的独立结果路径。
function M.exact_query(callback, sql, url, opts)
  return operation(callback, pack(sql, url, opts), {
    return_error = true, opts = opts, handoff = { sql = sql, url = url },
  })
end

-- 本地排序兼容层在 set_callbacks 之后包装回调；整个重查必须共享同一代结果。
function M.wrap_refresh(bufnr, name, callback)
  if not installed then return callback end
  return function(...)
    return operation(callback, pack(...), {
      bufnr = bufnr, refresh_handoff = { bufnr = bufnr, name = name },
    })
  end
end

function M.cancel()
  local cancelled = cancel_operation(foreground)
  if not cancelled then
    vim.notify("当前没有正在接收的 SQL 结果", vim.log.levels.INFO)
  end
  return cancelled
end

function M.get_limits()
  return vim.deepcopy(limits or budget.DEFAULTS)
end

local function mysql_batch(args)
  if type(args) ~= "table" then return false end
  local name = tostring(args[1] or ""):gsub("\\", "/"):match("([^/]+)$") or ""
  if name:lower() ~= "mysql" and name:lower() ~= "mysql.exe" then return false end
  for _, arg in ipairs(args) do if arg == "--batch" or arg == "-B" then return true end end
  return false
end

local function protected_call(callback, ...)
  local result = pack(pcall(callback, ...))
  if not result[1] then
    local err = message(result[2])
    if not err then error(result[2], 0) end
    vim.notify("SQL 结果保护：" .. err, vim.log.levels.WARN)
    return nil
  end
  return unpack(result, 2, result.n)
end

function M.install(opts)
  if installed then return end
  local normalized, err = budget.normalize_budget(opts)
  assert(normalized, err)
  limits = normalized
  local grip = require("dadbod-grip")
  local adapters = require("dadbod-grip.adapters")
  local mysql = require("dadbod-grip.adapters.mysql")
  local db = require("dadbod-grip.db")
  local data = require("dadbod-grip.data")
  local view = require("dadbod-grip.view")
  local importer = require("dadbod-grip.importer")
  local stream = require("config.sql-result-stream")
  assert(type(mysql.query) == "function" and type(adapters.run_cmd) == "function"
    and type(db.query) == "function" and type(data.new) == "function"
    and type(view.open) == "function" and type(view.render) == "function"
    and type(view.apply_edit) == "function" and type(view.set_callbacks) == "function"
    and type(importer.parse) == "function" and type(grip.do_import) == "function",
    "Dadbod Grip 结果接口已变化，请更新结果保护兼容层")

  local original_run, original_mysql, original_query = adapters.run_cmd, mysql.query, db.query
  local original_open, original_callbacks = grip.open, view.set_callbacks

  adapters.run_cmd = function(args, timeout, command_opts)
    local context = pending_mysql
    if context and mysql_batch(args) then
      -- 必须在 vim.wait 前消费。定时器中的元数据查询不会继承这个一次性标记。
      pending_mysql = nil
    elseif current and current.import_pending and args[1] == "sh" and args[2] == "-s" then
      context = { budget = limits, format = "bytes" }
      current.import_pending = false
    else
      return original_run(args, timeout, command_opts)
    end
    local owner = context.owner or current
    context.owner = nil
    check_live(owner)
    if owner then owner.contexts[context] = true end
    local next_opts = vim.tbl_extend("force", {}, command_opts or {}, { _sql_result_guard = context })
    local result = pack(pcall(function()
      if adapters._nvim_sql_credentials then return original_run(args, timeout, next_opts) end
      return stream.run(args, timeout, command_opts, context)
    end))
    if owner then owner.contexts[context] = nil end
    context.cancel = nil
    check_live(owner)
    if not result[1] then error(result[2], 0) end
    local reason = message(result[3])
    if reason and owner then abort(reason) end
    return unpack(result, 2, result.n)
  end

  mysql.query = function(...)
    local context = { budget = limits, owner = current }
    local previous = pending_mysql
    pending_mysql = context
    local result = pack(pcall(original_mysql, ...))
    -- 正常路径在 run_cmd 中已清除；调用提前失败时也不能泄漏到下一条命令。
    if pending_mysql == context then pending_mysql = previous end
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
  end

  db.query = function(...)
    local owner = current
    check_live(owner)
    local result, query_err = original_query(...)
    check_live(owner)
    if not result then
      if owner then owner.failure = query_err or "查询失败" end
      return nil, query_err
    end
    local ok, failure = budget.check_result(result, limits)
    if not ok then
      if owner then abort(failure) end
      return nil, failure
    end
    if owner then result_owner[result] = owner end
    return result, query_err
  end

  grip.open = function(arg, url, open_opts)
    if current and current.handoff and current.handoff.sql == arg and current.handoff.url == url then
      current.handoff = nil
      check_live(current)
      return original_open(arg, url, open_opts)
    end
    return operation(original_open, pack(arg, url, open_opts), { opts = open_opts })
  end

  view.set_callbacks = function(bufnr, callbacks)
    local wrapped = vim.tbl_extend("force", {}, callbacks)
    for name, callback in pairs(callbacks) do
      if type(callback) == "function" then
        if name == "on_requery" or name == "on_refresh" then
          wrapped[name] = function(...)
            local handoff = current and current.refresh_handoff
            if handoff and handoff.bufnr == bufnr and handoff.name == name then
              current.refresh_handoff = nil
              check_live(current)
              return callback(...)
            end
            return operation(callback, pack(...), { bufnr = bufnr })
          end
        else
          wrapped[name] = function(...) return protected_call(callback, ...) end
        end
      end
    end
    return original_callbacks(bufnr, wrapped)
  end

  local original_new = data.new
  data.new = function(result)
    local owner = result_owner[result] or current
    check_live(owner)
    local ok, failure = budget.check_result(result, limits)
    if not ok then abort(failure) end
    local state = original_new(result)
    if owner then state_owner[state] = owner end
    return state
  end

  local function check_state(state)
    -- 允许新结果的延迟重绘；不能把正在退栈的旧查询作用域传给新结果。
    check_live(state_owner[state])
    local ok, failure = budget.check_state(state, limits)
    if not ok then abort(failure) end
  end

  local original_view_open, original_render, original_edit = view.open, view.render, view.apply_edit
  local original_slack, rendering_session = view._distribute_slack, nil
  assert(type(original_slack) == "function", "Dadbod Grip 列宽接口已变化，请更新结果保护兼容层")
  view._distribute_slack = function(columns, widths, ...)
    original_slack(columns, widths, ...)
    local overrides = rendering_session and rendering_session.col_width_overrides or {}
    for _, column in ipairs(columns) do
      -- 自动布局不得把默认40继续扩宽；保留已有手动调宽功能及其200上限。
      widths[column] = math.min(widths[column], overrides[column] and 200 or 40)
    end
    return widths
  end
  view.open = function(state, url, sql, open_opts)
    check_live(current)
    check_state(state)
    if current then current.publishing = true end
    local result = pack(pcall(original_view_open, state, url, sql, open_opts))
    if current then
      current.publishing = false
      if result[1] then current.published_buf = result[2] end
    end
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
  end
  view.render = function(bufnr, state)
    check_state(state)
    local previous = rendering_session
    rendering_session = view._sessions[bufnr]
    local result = pack(pcall(original_render, bufnr, state))
    rendering_session = previous
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
  end
  view.apply_edit = function(bufnr, state)
    check_state(state)
    return original_edit(bufnr, state)
  end

  local original_insert, original_blank = data.insert_rows_with_values, data.insert_row
  local original_change, original_clone = data.add_change, data.clone_row
  data.insert_rows_with_values = function(state, after_idx, rows)
    local ok, failure = budget.check_insert(state, rows, limits)
    if not ok then abort(failure) end
    return original_insert(state, after_idx, rows)
  end
  data.insert_row = function(state, after_idx)
    local ok, failure = budget.check_insert(state, { {} }, limits)
    if not ok then abort(failure) end
    return original_blank(state, after_idx)
  end
  data.add_change = function(state, row_idx, field, value)
    local ok, failure = budget.check_change(state, row_idx, field, value, limits)
    if not ok then abort(failure) end
    return original_change(state, row_idx, field, value)
  end
  data.clone_row = function(state, row_idx)
    -- clone 的候选值最多只有已限制的列数，先检查后让插件复制 state。
    local values = {}
    for _, column in ipairs(state.columns) do values[column] = data.effective_value(state, row_idx, column) end
    local ok, failure = budget.check_insert(state, { values }, limits)
    if not ok then abort(failure) end
    return original_clone(state, row_idx)
  end

  local editor = require("dadbod-grip.editor")
  local original_editor_open = editor.open
  editor.open = function(prompt, initial_value, on_save, editor_opts)
    return original_editor_open(prompt, initial_value, function(...)
      return protected_call(on_save, ...)
    end, editor_opts)
  end

  local original_parse, original_import = importer.parse, grip.do_import
  importer.parse = function(raw, columns)
    local ok, failure = budget.check_import(raw, limits)
    if not ok then return nil, failure end
    local parsed, parse_err = original_parse(raw, columns)
    if not parsed then return nil, parse_err end
    local session = current and current.session
    local state = session and session.state or { rows = {}, columns = columns, inserted = {}, changes = {} }
    ok, failure = budget.check_insert(state, parsed.rows, limits)
    if not ok then return nil, failure end
    return parsed
  end
  grip.do_import = function(source)
    return operation(function()
      current.import_pending = true
      return original_import(source)
    end, pack(), { bufnr = vim.api.nvim_get_current_buf() })
  end

  local group = vim.api.nvim_create_augroup("SqlResultGuard", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed" }, {
    group = group,
    callback = function(event)
      for op in pairs(active) do
        local closed = event.event == "BufWipeout"
          and (event.buf == op.source_buf or event.buf == op.target_buf)
          or event.event == "WinClosed"
            and (tonumber(event.match) == op.source_win or tonumber(event.match) == op.target_win)
        if closed and not op.publishing then
          cancel_operation(op, "查询窗口已关闭；已丢弃本次结果")
        end
      end
    end,
  })
  vim.api.nvim_create_user_command("SQLCancel", M.cancel, { desc = "停止当前 SQL 结果接收并保留原结果" })
  installed = true
end

return M
