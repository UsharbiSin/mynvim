local M = {}

function M.connections()
  return require("config.sql-credentials").connections()
end

function M.current_connection(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local url = vim.b[bufnr].sql_connection_url
  if url and url ~= "" then
    return {
      name = vim.b[bufnr].sql_connection_name or "当前连接",
      url = url,
    }
  end
end

function M.select_connection(on_select)
  local items = M.connections()
  local source_buf = vim.api.nvim_get_current_buf()

  if #items == 0 then
    vim.notify(
      "没有找到完整的数据库普通连接参数（USER/HOST/PORT/NAME）",
      vim.log.levels.ERROR
    )
    return
  end

  vim.ui.select(items, {
    prompt = "选择当前 SQL 文件使用的数据库：",

    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if not choice then
      return
    end

    if vim.api.nvim_buf_is_valid(source_buf) then
      vim.b[source_buf].sql_connection_name = choice.name
      vim.b[source_buf].sql_connection_url = choice.url
    end

    vim.notify(
      "当前 SQL 连接：" .. choice.name,
      vim.log.levels.INFO
    )
    if on_select then
      on_select(choice)
    end
  end)
end

function M.with_connection(callback)
  local current = M.current_connection()
  if current then
    callback(current)
    return
  end
  M.select_connection(callback)
end

-- 这里只识别 CTE 头部和括号边界；外层 SELECT 的列来源由上游负责。
-- 不支持的前缀词法保持只读，避免把字符串/注释中的 SELECT 误当成外层。
local function cte_outer_select(sql, adapter_kind)
  local pos, length = 1, #sql
  local word_start, word_part = "[%a_\128-\255]", "[%w_$\128-\255]"
  local function next_token()
    while pos <= length do
      local char, pair = sql:sub(pos, pos), sql:sub(pos, pos + 1)
      if char:match("%s") then
        pos = pos + 1
      elseif pair == "--" or (char == "#" and adapter_kind == "mysql") then
        local following = sql:sub(pos + 2, pos + 2)
        if pair == "--" and adapter_kind == "mysql" and following ~= ""
            and not following:match("[%s%c]") then return nil end
        local newline = sql:find("[\r\n]", pos + 1)
        if newline and sql:sub(newline, newline) == "\r"
            and sql:sub(newline + 1, newline + 1) ~= "\n"
            and adapter_kind ~= "postgresql" and adapter_kind ~= "duckdb" then return nil end
        pos = newline and (newline + 1) or (length + 1)
      elseif pair == "/*" then
        if sql:sub(pos + 2, pos + 2) == "!"
            or sql:sub(pos + 2, pos + 3):upper() == "M!" then return nil end
        local close = sql:find("*/", pos + 2, true)
        local nested = sql:find("/*", pos + 2, true)
        if not close or (nested and nested < close) then return nil end
        pos = close + 2
      else
        break
      end
    end
    if pos > length then return nil end
    local first = pos
    local char = sql:sub(pos, pos)
    if char == "'" or char == '"' or char == "`" or char == "[" then
      if char == "`" and adapter_kind ~= "mysql" and adapter_kind ~= "sqlite" then return nil end
      if char == "[" and adapter_kind ~= "sqlite" and adapter_kind ~= "sqlserver" then return nil end
      local close = char == "[" and "]" or char
      local value = {}
      pos = pos + 1
      while pos <= length do
        local current = sql:sub(pos, pos)
        -- MySQL/PG 会话的转义选项可能改变引号边界，不能据此授权编辑。
        if current == "\\" then return nil end
        if current == close then
          if sql:sub(pos + 1, pos + 1) == close and (char ~= "[" or adapter_kind == "sqlserver") then
            value[#value + 1] = close
            pos = pos + 2
          else
            pos = pos + 1
            return { kind = char == "'" and "literal" or "ident", text = table.concat(value), start = first }
          end
        else
          value[#value + 1] = current
          pos = pos + 1
        end
      end
      return nil
    end
    -- dollar-string、未知转义和其它方言的 # 都不参与 CTE 编辑恢复。
    if char == "$" or char == "\\" or char == "#" then return nil end
    if char:match(word_start) then
      pos = pos + 1
      while pos <= length and sql:sub(pos, pos):match(word_part) do pos = pos + 1 end
      local value = sql:sub(first, pos - 1)
      return { kind = "word", text = value, upper = value:upper(), start = first }
    end
    pos = pos + 1
    return { kind = char, text = char, start = first }
  end

  local token = next_token()
  local function advance() token = next_token() end
  local function identifier()
    return token and (token.kind == "word" or token.kind == "ident")
  end
  if not token or token.upper ~= "WITH" then return nil end
  advance()
  if token and token.upper == "RECURSIVE" then advance() end

  local names = {}
  while identifier() do
    -- MySQL 的名称折叠依赖服务端字符集；Lua 无法可靠比较非 ASCII 名称。
    if adapter_kind == "mysql" and token.text:find("[\128-\255]") then return nil end
    names[token.text:lower()] = true
    advance()
    if token and token.kind == "(" then
      advance()
      if not identifier() then return nil end
      advance()
      while token and token.kind == "," do
        advance()
        if not identifier() then return nil end
        advance()
      end
      if not token or token.kind ~= ")" then return nil end
      advance()
    end
    if not token or token.upper ~= "AS" then return nil end
    advance()
    if token and token.upper == "NOT" then
      advance()
      if not token or token.upper ~= "MATERIALIZED" then return nil end
      advance()
    elseif token and token.upper == "MATERIALIZED" then
      advance()
    end
    if not token or token.kind ~= "(" then return nil end
    local depth = 0
    repeat
      if not token or token.kind == ";" then return nil end
      if token.kind == "(" then depth = depth + 1 end
      if token.kind == ")" then depth = depth - 1 end
      advance()
    until depth == 0
    if token and token.kind == "," then
      advance()
    else
      if not token or token.upper ~= "SELECT" then return nil end
      return sql:sub(token.start), names
    end
  end
end

local function infer_editable_table(sql, adapter_kind)
  if type(sql) ~= "string" or not sql:match("^%s*[Ww][Ii][Tt][Hh]%f[^%w_$]") then return nil end
  if not adapter_kind then return nil end
  local outer, names = cte_outer_select(sql, adapter_kind)
  if not outer then return nil end
  local resolve = require("dadbod-grip")._resolve_query
  if type(resolve) ~= "function" then return nil end

  -- lazy-lock.json 不入库；旧插件尚无 #78 的检查时，不启用 CTE 编辑扩展。
  local ok, probe, unsafe_table = pcall(resolve, "SELECT id + 1 AS id FROM _sql_runner_probe", 1, adapter_kind)
  if not ok or not probe or not probe.is_raw or unsafe_table ~= nil then return nil end
  local resolved, spec, table_name, file_path, mutation = pcall(resolve, outer, 1, adapter_kind)
  if not resolved or not spec or not spec.is_raw or type(table_name) ~= "string"
      or file_path or mutation then return nil end
  if not table_name:find(".", 1, true) then
    if adapter_kind == "mysql" and table_name:find("[\128-\255]") then return nil end
    if names[table_name:lower()] then return nil end
  end
  return table_name
end

local function has_primary_key_columns(state, primary_keys)
  if not state or type(primary_keys) ~= "table" or #primary_keys == 0 then return false end
  local columns = {}
  for _, column in ipairs(state.columns or {}) do
    columns[column] = (columns[column] or 0) + 1
  end
  for _, primary_key in ipairs(primary_keys) do
    -- 不能把 PostgreSQL 的非主键 "ID" 当成真正的主键 id，也拒绝重名结果列。
    if columns[primary_key] ~= 1 then return false end
  end
  return true
end

local function restore_editable_state(state, spec, connection)
  if not state or state.table_name ~= nil or not spec or not spec.is_raw then return false end
  local db = require("dadbod-grip.db")
  if state.url ~= connection or db.is_readonly(connection) then return false end
  local kind = require("dadbod-grip.adapters").kind(db.resolved_url(connection))
  local table_name = infer_editable_table(spec.base_sql, kind)
  if not table_name then return false end

  local query = require("dadbod-grip.query")
  local plain = #(spec.filters or {}) == 0 and #(spec.sorts or {}) == 0 and (spec.page or 1) == 1
  if not (plain and state.sql == spec.base_sql) then
    local ok, expected = pcall(query.build_sql, spec)
    if not ok or state.sql ~= expected then return false end
  end
  -- 筛选/排序片段也可能追加 UNION 等结构；使用相同构造器验证外层修饰。
  -- 此 SQL 仅交给解析器，不会执行，也不会改变用户原查询。
  local modifiers = vim.deepcopy(spec)
  modifiers.is_raw, modifiers.base_sql, modifiers.table_name = false, nil, table_name
  local built, modifier_sql = pcall(query.build_sql, modifiers)
  if not built then return false end
  local checked, _, source = pcall(require("dadbod-grip")._resolve_query, modifier_sql, 1, kind)
  if not checked or source ~= table_name then return false end

  local primary_keys, pk_err = db.get_primary_keys(table_name, connection)
  if pk_err or not has_primary_key_columns(state, primary_keys) then return false end
  state.table_name = table_name
  state.pks = vim.deepcopy(primary_keys)
  state.readonly = false
  return true
end

local function install_editable_refresh(session)
  if session._sql_runner_editable_refresh then return end
  local view = require("dadbod-grip.view")
  local db = require("dadbod-grip.db")
  local function wrap(callback)
    return function(bufnr, next_spec)
      local current = view._sessions[bufnr]
      if not current or not current.state then return callback(bufnr, next_spec) end
      local previous_state, previous_spec = current.state, current.query_spec
      local previous_sql, previous_total = current.query_sql, current.total_rows
      local previous_table = previous_state.table_name
      -- 上游 on_refresh 会沿用 state.table_name；先撤下本地补充的表名，
      -- 让新结果从只读状态重新核验，旧结果本身保留以便查询失败时恢复。
      previous_state.table_name = nil
      local ok, err = pcall(callback, bufnr, next_spec)
      previous_state.table_name = previous_table
      current = view._sessions[bufnr]
      if current and current.state == previous_state then
        current.query_spec, current.query_sql = previous_spec, previous_sql
        current.total_rows = previous_total
        if db.is_readonly(current.url) then
          previous_state.table_name, previous_state.pks, previous_state.readonly = nil, {}, true
          view.render(bufnr, previous_state)
        end
      elseif ok and current and current.state then
        local sql_changed = current.query_sql ~= current.state.sql
        current.query_sql = current.state.sql
        local restored = restore_editable_state(current.state, current.query_spec, current.url)
        if restored or sql_changed then view.render(bufnr, current.state) end
      end
      if not ok then error(err, 0) end
    end
  end
  for _, name in ipairs({ "on_requery", "on_refresh" }) do
    if type(session[name]) == "function" then session[name] = wrap(session[name]) end
  end
  session._sql_runner_editable_refresh = true
end

local function open_exact_query_impl(sql, url, opts)
  local query = require("dadbod-grip.query")
  local grip = require("dadbod-grip")
  local view = require("dadbod-grip.view")
  local cleaned_sql = sql and sql:gsub(";%s*$", "") or sql

  local original_build_sql = query.build_sql
  local original_page_info = query.page_info
  local original_view_open = view.open

  -- 自动 COUNT 已禁用；原 SQL 的完整结果已在内存中，首屏直接用返回行数，
  -- 不等待额外渲染，也不把超过 1000 行的完整结果误显示为可继续分页。
  view.open = function(result_state, connection, query_sql, view_opts)
    local spec = view_opts and view_opts.query_spec
    if spec and spec.is_raw and spec.base_sql == cleaned_sql then
      local row_count = #(result_state.rows or {})
      spec.page, spec.page_size = 1, math.max(row_count, 1)
      view_opts = vim.tbl_extend("force", {}, view_opts, { total_rows = row_count })

      -- 普通 SELECT 保留上游的只读判断，仅为通过验证的 CTE 补充编辑元数据。
      restore_editable_state(result_state, spec, connection)
    end
    return original_view_open(result_state, connection, query_sql, view_opts)
  end

  -- Dadbod Grip 默认会把原始 SELECT 包成子查询后再追加分页 LIMIT。
  -- <leader>sr 要严格执行用户写下的查询，因此首轮查询直接交给数据库。
  query.build_sql = function(spec, build_opts)
    if spec.is_raw
        and spec.base_sql == cleaned_sql
        and #(spec.filters or {}) == 0
        and #(spec.sorts or {}) == 0
        and (spec.page or 1) == 1 then
      return spec.base_sql
    end
    return original_build_sql(spec, build_opts)
  end

  -- 首次渲染时就把原始查询视为一个完整结果集，避免显示成“第 1/N 页”。
  query.page_info = function(spec, total_rows)
    if spec.is_raw and spec.base_sql == cleaned_sql and total_rows ~= nil then
      return ("Page 1/1 (%d rows)"):format(total_rows)
    end
    return original_page_info(spec, total_rows)
  end

  local ok, err = xpcall(function()
    grip.open(sql, url, opts)
  end, debug.traceback)

  query.build_sql = original_build_sql
  query.page_info = original_page_info
  view.open = original_view_open

  if not ok then return false, err end

  -- open() 是同步的，返回后当前 buffer 已经是结果表。把分页大小同步成
  -- 实际取得的行数，后续本地排序/重绘时仍保持“完整结果集”的语义。
  local result_buf = vim.api.nvim_get_current_buf()
  local session = view._sessions[result_buf]
  if session
      and session.state
      and session.query_spec
      and session.query_spec.is_raw
      and session.query_spec.base_sql == cleaned_sql then
    local row_count = #(session.state.rows or {})
    session.query_spec.page = 1
    session.query_spec.page_size = math.max(row_count, 1)
    session.total_rows = row_count

    if cleaned_sql:match("^%s*[Ww][Ii][Tt][Hh]%f[^%w_$]") then
      install_editable_refresh(session)
    end
  end

  return true
end

local function open_exact_query(sql, url, opts)
  return require("config.sql-result-guard").exact_query(open_exact_query_impl, sql, url, opts)
end

M._open_exact_query = open_exact_query
M._infer_editable_table = infer_editable_table

function M.run(sql)
  local source_buf = vim.api.nvim_get_current_buf()
  local current = M.current_connection()
  local url = current and current.url

  if not url then
    vim.notify(
      "当前 SQL 文件还没有选择数据库，请先按 <leader>sc",
      vim.log.levels.WARN
    )
    return
  end

  if not sql or sql:match("^%s*$") then
    vim.notify(
      "没有可执行的 SQL",
      vim.log.levels.WARN
    )
    return
  end

  local ok, err = open_exact_query(sql, url, {
    source_path = vim.api.nvim_buf_get_name(source_buf),
  })
  if not ok then
    vim.notify("SQL 执行失败：" .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.run_buffer()
  local lines = vim.api.nvim_buf_get_lines(
    0,
    0,
    -1,
    false
  )

  M.run(table.concat(lines, "\n"))
end

function M.run_visual()
  local start_line = vim.fn.line("'<") - 1
  local end_line = vim.fn.line("'>")

  local lines = vim.api.nvim_buf_get_lines(
    0,
    start_line,
    end_line,
    false
  )

  M.run(table.concat(lines, "\n"))
end

return M
