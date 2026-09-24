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

local function sql_tokens(sql)
  local tokens = {}
  local depth = 0
  local i = 1
  local length = #sql

  local function add(kind, text, start_pos, end_pos)
    if depth ~= 0 then return end
    tokens[#tokens + 1] = {
      kind = kind,
      text = text,
      upper = kind == "word" and text:upper() or nil,
      start_pos = start_pos,
      end_pos = end_pos,
    }
  end

  while i <= length do
    local char = sql:sub(i, i)
    local next_char = sql:sub(i + 1, i + 1)

    if char:match("%s") then
      i = i + 1
    elseif char == "-" and next_char == "-" then
      local newline = sql:find("\n", i + 2, true)
      i = newline and (newline + 1) or (length + 1)
    elseif char == "#" then
      local newline = sql:find("\n", i + 1, true)
      i = newline and (newline + 1) or (length + 1)
    elseif char == "/" and next_char == "*" then
      local close = sql:find("*/", i + 2, true)
      i = close and (close + 2) or (length + 1)
    elseif char == "'" then
      i = i + 1
      while i <= length do
        local current = sql:sub(i, i)
        if current == "\\" then
          i = i + 2
        elseif current == "'" and sql:sub(i + 1, i + 1) == "'" then
          i = i + 2
        elseif current == "'" then
          i = i + 1
          break
        else
          i = i + 1
        end
      end
    elseif char == "`" or char == '"' then
      local quote = char
      local start_pos = i
      local value = {}
      i = i + 1
      while i <= length do
        local current = sql:sub(i, i)
        if current == quote and sql:sub(i + 1, i + 1) == quote then
          value[#value + 1] = quote
          i = i + 2
        elseif current == quote then
          i = i + 1
          break
        else
          value[#value + 1] = current
          i = i + 1
        end
      end
      add("ident", table.concat(value), start_pos, i - 1)
    elseif char == "[" then
      local start_pos = i
      local close = sql:find("]", i + 1, true)
      if not close then break end
      add("ident", sql:sub(i + 1, close - 1), start_pos, close)
      i = close + 1
    elseif char == "(" then
      if depth == 0 then add("lparen", char, i, i) end
      depth = depth + 1
      i = i + 1
    elseif char == ")" then
      if depth > 0 then depth = depth - 1 end
      if depth == 0 then add("rparen", char, i, i) end
      i = i + 1
    elseif char == "," then
      add("comma", char, i, i)
      i = i + 1
    elseif char == "." then
      add("dot", char, i, i)
      i = i + 1
    elseif char == ";" then
      add("semicolon", char, i, i)
      i = i + 1
    elseif char:match("[%a_]") then
      local start_pos = i
      i = i + 1
      while i <= length and sql:sub(i, i):match("[%w_$]") do
        i = i + 1
      end
      add("word", sql:sub(start_pos, i - 1), start_pos, i - 1)
    else
      i = i + 1
    end
  end

  return tokens
end

local function infer_editable_table(sql)
  if not sql or sql:match("^%s*$") then return nil end

  local tokens = sql_tokens(sql)
  if #tokens == 0 or tokens[1].kind ~= "word" then return nil end

  local cte_names = {}
  local main_select

  if tokens[1].upper == "WITH" then
    local index = 2
    if tokens[index] and tokens[index].upper == "RECURSIVE" then index = index + 1 end

    while tokens[index] do
      local name = tokens[index]
      if name.kind ~= "word" and name.kind ~= "ident" then return nil end
      cte_names[name.text:lower()] = true
      index = index + 1

      -- Optional CTE column list: cte_name(col1, col2) AS (...)
      if tokens[index] and tokens[index].kind == "lparen" then
        if not tokens[index + 1] or tokens[index + 1].kind ~= "rparen" then return nil end
        index = index + 2
      end

      if not tokens[index] or tokens[index].upper ~= "AS" then return nil end
      index = index + 1
      if tokens[index] and tokens[index].upper == "NOT" and tokens[index + 1]
          and tokens[index + 1].upper == "MATERIALIZED" then
        index = index + 2
      elseif tokens[index] and tokens[index].upper == "MATERIALIZED" then
        index = index + 1
      end

      if not tokens[index] or tokens[index].kind ~= "lparen"
          or not tokens[index + 1] or tokens[index + 1].kind ~= "rparen" then
        return nil
      end
      index = index + 2

      if tokens[index] and tokens[index].kind == "comma" then
        index = index + 1
      else
        main_select = index
        break
      end
    end
  elseif tokens[1].upper == "SELECT" then
    main_select = 1
  else
    return nil
  end

  if not main_select or not tokens[main_select] or tokens[main_select].upper ~= "SELECT" then
    return nil
  end

  local from_index
  local disallowed = {
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    GROUP = true,
    HAVING = true,
    WINDOW = true,
    QUALIFY = true,
  }
  for index = main_select + 1, #tokens do
    local token = tokens[index]
    if token.kind == "word" then
      if disallowed[token.upper] then return nil end
      if not from_index and token.upper == "FROM" then from_index = index end
    end
  end
  if not from_index then return nil end

  local clause_keywords = {
    WHERE = true,
    GROUP = true,
    HAVING = true,
    ORDER = true,
    LIMIT = true,
    OFFSET = true,
    UNION = true,
    INTERSECT = true,
    EXCEPT = true,
    FOR = true,
    LOCK = true,
    WINDOW = true,
    QUALIFY = true,
  }
  local clause_end = #tokens + 1
  for index = from_index + 1, #tokens do
    local token = tokens[index]
    if token.kind == "word" and clause_keywords[token.upper] then
      clause_end = index
      break
    elseif token.kind == "semicolon" then
      clause_end = index
      break
    end
  end

  local index = from_index + 1
  local first = tokens[index]
  if not first or (first.kind ~= "word" and first.kind ~= "ident") then return nil end

  local parts = { first.text }
  index = index + 1
  while index < clause_end and tokens[index].kind == "dot" do
    local part = tokens[index + 1]
    if not part or (part.kind ~= "word" and part.kind ~= "ident") then return nil end
    parts[#parts + 1] = part.text
    index = index + 2
  end

  -- FROM 后只允许一个可选别名；JOIN、逗号多表、索引提示等都保持只读。
  local remaining = clause_end - index
  if remaining == 1 then
    local alias = tokens[index]
    if alias.kind ~= "word" and alias.kind ~= "ident" then return nil end
  elseif remaining == 2 then
    local as_token = tokens[index]
    local alias = tokens[index + 1]
    if as_token.upper ~= "AS" or (alias.kind ~= "word" and alias.kind ~= "ident") then
      return nil
    end
  elseif remaining ~= 0 then
    return nil
  end

  if #parts == 1 and cte_names[parts[1]:lower()] then return nil end
  return table.concat(parts, ".")
end

local function has_primary_key_columns(state, primary_keys)
  if not state or type(primary_keys) ~= "table" or #primary_keys == 0 then return false end
  local columns = {}
  for _, column in ipairs(state.columns or {}) do
    columns[tostring(column):lower()] = true
  end
  for _, primary_key in ipairs(primary_keys) do
    if not columns[tostring(primary_key):lower()] then return false end
  end
  return true
end

local function restore_editable_state(state, table_name, primary_keys)
  if not state or state.table_name ~= nil then return false end
  if not has_primary_key_columns(state, primary_keys) then return false end
  state.table_name = table_name
  state.pks = vim.deepcopy(primary_keys)
  state.readonly = false
  return true
end

local function open_exact_query(sql, url, opts)
  local query = require("dadbod-grip.query")
  local grip = require("dadbod-grip")
  local view = require("dadbod-grip.view")
  local db = require("dadbod-grip.db")
  local cleaned_sql = sql and sql:gsub(";%s*$", "") or sql
  local editable_table = infer_editable_table(cleaned_sql)
  local editable_primary_keys

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

      -- dadbod-grip 会把 WITH 查询统一视为 table_name=nil。这里只在能从最外层
      -- SELECT 安全确定唯一真实表、连接可写、且结果包含完整主键时恢复编辑能力。
      if editable_table and result_state.table_name == nil and not db.is_readonly(connection) then
        local primary_keys, pk_err = db.get_primary_keys(editable_table, connection)
        if not pk_err and restore_editable_state(result_state, editable_table, primary_keys) then
          editable_primary_keys = vim.deepcopy(primary_keys)
        end
      end
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

    -- raw query 新增筛选等操作后会重新查询；上游会再次丢掉 table_name。
    -- 把已经验证过的底表/主键补回，避免编辑能力刷新一次就消失。
    if editable_primary_keys and session.on_requery and not session._sql_runner_editable_requery then
      local original_on_requery = session.on_requery
      session._sql_runner_editable_requery = true
      session.on_requery = function(target_bufnr, next_spec)
        original_on_requery(target_bufnr, next_spec)
        local current = view._sessions[target_bufnr]
        if current and restore_editable_state(current.state, editable_table, editable_primary_keys) then
          view.render(target_bufnr, current.state)
        end
      end
    end
  end

  return true
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
