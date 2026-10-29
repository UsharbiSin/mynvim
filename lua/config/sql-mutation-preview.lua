local M = {}

-- Match the installed MySQL adapter's ANSI_QUOTES, NO_BACKSLASH_ESCAPES mode.
-- Token positions let preview clauses keep their original comments and newlines.
local function tokenize(sql)
  if type(sql) ~= "string" or sql:find("%z") then return nil, "SQL 文本无效" end
  local tokens, pos, depth = {}, 1, 0
  while pos <= #sql do
    local first = pos
    local char, pair = sql:sub(pos, pos), sql:sub(pos, pos + 1)
    if char:match("%s") then
      pos = pos + 1
    elseif char == "#" or (pair == "--"
        and (pos + 2 > #sql or sql:sub(pos + 2, pos + 2):match("[%s%c]"))) then
      local newline = sql:find("[\r\n]", pos + 1)
      if newline and sql:sub(newline, newline) == "\r"
          and sql:sub(newline + 1, newline + 1) ~= "\n" then
        return nil, "行注释包含不明确的独立 CR 换行"
      end
      pos = newline and (newline + 1) or (#sql + 1)
    elseif pair == "/*" then
      local marker = sql:sub(pos + 2, pos + 3):upper()
      if marker:sub(1, 1) == "!" or marker:sub(1, 1) == "+" or marker == "M!" then
        return nil, "暂不预览含可执行注释或优化器提示的 SQL"
      end
      local close, nested = sql:find("*/", pos + 2, true), sql:find("/*", pos + 2, true)
      if not close or (nested and nested < close) then return nil, "块注释未闭合或发生嵌套" end
      pos = close + 2
    elseif char == "'" or char == '"' or char == string.char(96) then
      local quote, closed = char, false
      pos = pos + 1
      while pos <= #sql do
        if sql:sub(pos, pos) == quote then
          if sql:sub(pos + 1, pos + 1) == quote then
            pos = pos + 2
          else
            closed, pos = true, pos + 1
            break
          end
        else
          pos = pos + 1
        end
      end
      if not closed then return nil, "引号未闭合" end
      tokens[#tokens + 1] = {
        kind = quote == "'" and "string" or "ident", start = first, finish = pos - 1,
        text = (sql:sub(first + 1, pos - 2):gsub(quote .. quote, quote)), depth = depth,
      }
    elseif char:match("[%a_$\128-\255]") then
      pos = pos + 1
      while pos <= #sql and sql:sub(pos, pos):match("[%w_$\128-\255]") do pos = pos + 1 end
      local word = sql:sub(first, pos - 1)
      tokens[#tokens + 1] = {
        kind = "word", text = word, upper = word:upper(), start = first, finish = pos - 1, depth = depth,
      }
    elseif char:match("%d") then
      local number = sql:sub(pos):match("^%d+%.?%d*[eE][+-]?%d+")
        or sql:sub(pos):match("^%d+%.?%d*")
      pos = pos + #number
      tokens[#tokens + 1] = {
        kind = "number", text = number, start = first, finish = pos - 1, depth = depth,
      }
    else
      if char == "\\" then return nil, "暂不预览包含客户端反斜杠命令的 SQL" end
      if char == ")" then depth = depth - 1 end
      if depth < 0 then return nil, "括号不匹配" end
      tokens[#tokens + 1] = { kind = char, text = char, start = pos, finish = pos, depth = depth }
      if char == "(" then depth = depth + 1 end
      pos = pos + 1
    end
  end
  if depth ~= 0 then return nil, "括号不匹配" end
  return tokens
end

local function identifier(token)
  return token and (token.kind == "word" or token.kind == "ident")
end

-- Only predict unambiguous literal assignments; expressions remain database work.
local function assignments(tokens, first, last, table_parts, alias)
  local result, seen = {}, {}
  local function read_assignment(from, to)
    local path, at = {}, from
    if not identifier(tokens[at]) then return end
    path[#path + 1], at = tokens[at].text, at + 1
    while at < to and tokens[at].kind == "." and identifier(tokens[at + 1]) do
      path[#path + 1], at = tokens[at + 1].text, at + 2
    end
    if not tokens[at] or tokens[at].kind ~= "=" then return end
    local column = path[#path]
    local qualifier = table.concat(path, ".", 1, #path - 1):lower()
    if #path > 1 and qualifier ~= (alias or ""):lower()
        and qualifier ~= table.concat(table_parts, "."):lower()
        and qualifier ~= table_parts[#table_parts]:lower() then return end
    local key = column:lower()
    if seen[key] then
      result[key] = nil
      return
    end
    seen[key] = true
    at = at + 1
    local value, is_null
    if at == to and tokens[at].kind == "string" then
      value = tokens[at].text
      -- Upstream add_change treats "" as NULL; leave empty-string display unchanged.
      if value == "" then return end
    elseif at == to and tokens[at].kind == "number" then
      value = tokens[at].text
    elseif at == to and tokens[at].upper == "NULL" then
      is_null = true
    elseif at + 1 == to and (tokens[at].kind == "+" or tokens[at].kind == "-")
        and tokens[to].kind == "number" then
      value = tokens[at].text .. tokens[to].text
    else
      return
    end
    result[key] = { column = column, value = value, is_null = is_null }
  end
  local start = first
  for index = first, last do
    if tokens[index].kind == "," and tokens[index].depth == 0 then
      read_assignment(start, index - 1)
      start = index + 1
    end
  end
  read_assignment(start, last)
  return result
end

function M.parse_update(sql)
  local tokens, err = tokenize(sql)
  if not tokens then return nil, err end
  if not tokens[1] or tokens[1].upper ~= "UPDATE" then return nil, "需要单条 UPDATE" end
  local last, terminator = #tokens, nil
  for index, token in ipairs(tokens) do
    if token.kind == ";" then
      if index ~= #tokens or token.depth ~= 0 then return nil, "请仅选择一条 UPDATE 进行预览" end
      last, terminator = index - 1, token
    end
  end
  local index = 2
  if tokens[index] and tokens[index].upper == "LOW_PRIORITY" then index = index + 1 end
  if tokens[index] and tokens[index].upper == "IGNORE" then index = index + 1 end
  local source_start = tokens[index] and tokens[index].start
  local parts = {}
  if not identifier(tokens[index]) then return nil, "无法识别 UPDATE 表名" end
  parts[#parts + 1], index = tokens[index].text, index + 1
  if tokens[index] and tokens[index].kind == "." and identifier(tokens[index + 1]) then
    parts[#parts + 1], index = tokens[index + 1].text, index + 2
  end
  for _, part in ipairs(parts) do
    if part:find(".", 1, true) then return nil, "暂不预览名称自身包含点号的表" end
  end
  local alias
  if tokens[index] and tokens[index].upper == "AS" then
    index = index + 1
    if not identifier(tokens[index]) then return nil, "表别名不完整" end
    alias, index = tokens[index].text, index + 1
  elseif identifier(tokens[index]) and tokens[index].upper ~= "SET" then
    alias, index = tokens[index].text, index + 1
  end
  if not tokens[index] or tokens[index].upper ~= "SET" then
    return nil, "当前预览支持单表 UPDATE，暂不支持 JOIN、多表或 PARTITION 结构"
  end
  local set_index, tail = index, nil
  local select_only = {
    INTO = true, UNION = true, EXCEPT = true, INTERSECT = true,
    FOR = true, LOCK = true, PROCEDURE = true,
  }
  for at = set_index + 1, last do
    local token = tokens[at]
    -- Reserved words after a dot are column names (for example t.where).
    if token.depth == 0 and tokens[at - 1].kind ~= "." then
      if select_only[token.upper] then
        return nil, "UPDATE 中包含不支持的 SELECT 子句，无法生成只读预览"
      end
      if not tail and (token.upper == "WHERE" or token.upper == "LIMIT"
          or (token.upper == "ORDER" and tokens[at + 1] and tokens[at + 1].upper == "BY")) then
        tail = at
      end
    end
  end
  local set_last = (tail or (last + 1)) - 1
  if set_last <= set_index then return nil, "SET 赋值不完整" end
  local preview = "SELECT * FROM " .. sql:sub(source_start, tokens[set_index].start - 1)
  if tail then
    local suffix = sql:sub(tokens[tail].start)
    if terminator then
      suffix = sql:sub(tokens[tail].start, terminator.start - 1) .. sql:sub(terminator.finish + 1)
    end
    preview = preview .. "\n" .. suffix
  end
  return {
    sql = preview, table_name = table.concat(parts, "."),
    assignments = assignments(tokens, set_index + 1, set_last, parts, alias),
  }
end

-- Preserve the entire source and suffix: DELETE previews must retain aliases,
-- comment boundaries and limits, just like the original statement.
function M.parse_delete(sql)
  local tokens, err = tokenize(sql)
  if not tokens then return nil, err end
  if not tokens[1] or tokens[1].upper ~= "DELETE" then return nil, "需要单条 DELETE" end
  local last, terminator = #tokens, nil
  for index, token in ipairs(tokens) do
    if token.kind == ";" then
      if index ~= #tokens or token.depth ~= 0 then return nil, "请仅选择一条 DELETE 进行预览" end
      last, terminator = index - 1, token
    end
  end
  local function path(at)
    if at > last or not identifier(tokens[at]) then return nil, at end
    local parts = { tokens[at].text }
    at = at + 1
    if at < last and tokens[at].kind == "." and identifier(tokens[at + 1]) then
      parts[#parts + 1], at = tokens[at + 1].text, at + 2
    end
    for _, part in ipairs(parts) do
      if part:find(".", 1, true) then return nil, at end
    end
    return parts, at
  end
  local function keyword(at, word)
    return at <= last and tokens[at] and tokens[at].upper == word
  end
  local index = 2
  for _, modifier in ipairs({ "LOW_PRIORITY", "QUICK", "IGNORE" }) do
    if keyword(index, modifier) then index = index + 1 end
  end
  local from_first = keyword(index, "FROM")
  if from_first then index = index + 1 end
  local source_start = tokens[index] and tokens[index].start
  local parts
  parts, index = path(index)
  if not parts then return nil, "无法识别 DELETE 表名或目标" end
  local wildcard = index < last and tokens[index].kind == "." and tokens[index + 1].kind == "*"
  if wildcard then index = index + 2 end
  local target
  if not from_first or keyword(index, "USING") then
    target = parts
    if not keyword(index, from_first and "USING" or "FROM") then
      return nil, "当前预览仅支持单个 DELETE 目标"
    end
    index = index + 1
    source_start = tokens[index] and tokens[index].start
    parts, index = path(index)
    if not parts then return nil, "无法识别 DELETE 来源表" end
  elseif wildcard then
    return nil, "DELETE 目标通配符需要 FROM 或 USING 来源"
  end
  local alias
  local boundaries = {
    WHERE = true, ORDER = true, LIMIT = true, JOIN = true, INNER = true,
    LEFT = true, RIGHT = true, CROSS = true, NATURAL = true,
    STRAIGHT_JOIN = true, PARTITION = true, USING = true,
  }
  if keyword(index, "AS") then
    index = index + 1
    if index > last or not identifier(tokens[index]) then return nil, "表别名不完整" end
    alias, index = tokens[index].text, index + 1
  elseif index <= last and identifier(tokens[index]) and not boundaries[tokens[index].upper] then
    alias, index = tokens[index].text, index + 1
  end
  if index <= last and not (keyword(index, "WHERE") or keyword(index, "LIMIT")
      or (keyword(index, "ORDER") and keyword(index + 1, "BY"))) then
    return nil, "当前预览支持单表 DELETE，暂不支持 JOIN、多表或 PARTITION 结构"
  end
  if target then
    local name = table.concat(target, ".")
    local matches = alias and name == alias
      or (not alias and (name == table.concat(parts, ".") or name == parts[#parts]))
    if not matches then return nil, "DELETE 目标与来源表或别名不匹配" end
  end
  local select_only = {
    INTO = true, UNION = true, EXCEPT = true, INTERSECT = true,
    FOR = true, LOCK = true, PROCEDURE = true, RETURNING = true,
  }
  for at = index, last do
    if target and tokens[at].depth == 0 and tokens[at - 1].kind ~= "."
        and (tokens[at].upper == "ORDER" or tokens[at].upper == "LIMIT") then
      return nil, "带 DELETE 目标列表的语法不支持 ORDER BY 或 LIMIT"
    end
    if select_only[tokens[at].upper] and tokens[at - 1].kind ~= "." then
      return nil, "DELETE 中包含不支持的 SELECT 子句，无法生成只读预览"
    end
  end
  local source = sql:sub(source_start)
  if terminator then
    source = sql:sub(source_start, terminator.start - 1) .. sql:sub(terminator.finish + 1)
  end
  return { sql = "SELECT * FROM " .. source, table_name = table.concat(parts, ".") }
end

local function open_mutation(plan, original_sql, url, stmt_type, opts)
  local db, data = require("dadbod-grip.db"), require("dadbod-grip.data")
  local view, query = require("dadbod-grip.view"), require("dadbod-grip.query")
  local function fetch()
    local result, err = db.query(plan.sql, url)
    if not result then return nil, err or "query failed" end
    if #result.columns == 0 then
      for _, column in ipairs(db.get_column_info(plan.table_name, url) or {}) do
        result.columns[#result.columns + 1] = column.column_name
      end
    end
    result.readonly = db.is_readonly(url)
    local pks, pk_err
    if not result.readonly then pks, pk_err = db.get_primary_keys(plan.table_name, url) end
    result.primary_keys = not pk_err and pks or {}
    result.table_name, result.url, result.sql = plan.table_name, url, plan.sql
    local state = data.new(result)
    if stmt_type == "DELETE" then
      for row = 1, #state.rows do state = data.toggle_delete(state, row) end
    else
      for _, column in ipairs(state.columns) do
        local assignment = plan.assignments[column:lower()]
        if assignment then
          for row = 1, #state.rows do
            state = data.add_change(state, row, column, assignment.value)
          end
        end
      end
    end
    return state
  end

  local state, err = fetch()
  if not state then
    vim.notify(stmt_type .. " 预览失败：" .. tostring(err), vim.log.levels.ERROR)
    return
  end
  local spec = query.new_raw(plan.sql, math.max(#state.rows, 1))
  local view_opts = vim.tbl_extend("force", {}, opts or {}, {
    max_col_width = require("dadbod-grip").get_opts().max_col_width,
    query_spec = spec, total_rows = #state.rows,
  })
  local bufnr = view.open(state, url, plan.sql, view_opts)
  local session = view._sessions[bufnr]
  if not session then return end
  session.pending_mutation = {
    sql = original_sql, type = stmt_type, table_name = plan.table_name, row_count = #state.rows,
  }
  local function render(next_state)
    local count = #next_state.rows
    session.pending_mutation.row_count = count
    session._mutation_title = ("%s %s (%d rows)"):format(stmt_type, plan.table_name, count)
    session.query_spec.page, session.query_spec.page_size = 1, math.max(count, 1)
    session.total_rows = count
    view.render(bufnr, next_state)
  end
  view.set_callbacks(bufnr, {
    on_refresh = function()
      if view._sessions[bufnr] ~= session or not session.pending_mutation then return end
      local next_state, refresh_err = fetch()
      if not next_state then
        vim.notify(stmt_type .. " 预览失败：" .. tostring(refresh_err), vim.log.levels.ERROR)
        return
      end
      if view._sessions[bufnr] ~= session or not session.pending_mutation then return end
      render(next_state)
    end,
  })
  render(state)
  return bufnr
end

function M.install()
  local grip = require("dadbod-grip")
  local installed = grip._nvim_sql_mutation_preview
  local version = 2
  if type(installed) == "table" and installed.version == version
      and grip._mutation_preview == installed.wrapper then return end
  local original = assert(grip._mutation_preview, "Dadbod Grip mutation preview interface changed")
  if type(installed) == "table" and original == installed.wrapper then
    original = installed.original
  end
  local function wrapper(sql, url, stmt_type, opts)
    local db = require("dadbod-grip.db")
    if (stmt_type ~= "UPDATE" and stmt_type ~= "DELETE")
        or require("dadbod-grip.adapters").kind(db.resolved_url(url)) ~= "mysql" then
      return original(sql, url, stmt_type, opts)
    end
    local parser = stmt_type == "DELETE" and M.parse_delete or M.parse_update
    local plan, err = parser(sql)
    if not plan then
      vim.notify(stmt_type .. " 预览失败：" .. err, vim.log.levels.ERROR)
      return
    end
    return open_mutation(plan, sql, url, stmt_type, opts)
  end
  grip._mutation_preview = wrapper
  grip._nvim_sql_mutation_preview = { version = version, original = original, wrapper = wrapper }
end

return M
