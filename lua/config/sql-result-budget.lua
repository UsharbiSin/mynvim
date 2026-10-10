-- SQL 结果的统一预算；只计量已有数据，不复制行、不读取数据库、不操作界面。
local M = {}

M.DEFAULTS = {
  max_rows = 10000,
  max_cells = 200000,
  max_columns = 256,
  max_bytes = 16 * 1024 * 1024,
  max_stderr_bytes = 65536,
}

local EMPTY = {}
local PREFIX = "[SQL_RESULT_GUARD] "
local METRICS = {
  { "bytes", "max_bytes", "数据字节数" },
  { "columns", "max_columns", "列数" },
  { "rows", "max_rows", "数据行数" },
  { "cells", "max_cells", "单元格数" },
}
local MAX_INTEGER = 9007199254740991

local function integer(value, minimum)
  return type(value) == "number" and value == value
    and value >= minimum and value <= MAX_INTEGER and value % 1 == 0
end

--- 返回独立的预算表；禁止 0、负数、NaN、无穷大和拼错的配置项。
function M.normalize_budget(opts)
  if opts ~= nil and type(opts) ~= "table" then
    return nil, PREFIX .. "预算配置必须是表。"
  end
  opts = opts or EMPTY
  for key in pairs(opts) do
    if M.DEFAULTS[key] == nil then
      return nil, PREFIX .. "预算配置包含未知配置项。"
    end
  end
  local limits = {}
  for key, default in pairs(M.DEFAULTS) do
    local value = opts[key]
    if value == nil then value = default end
    if not integer(value, 1) then
      return nil, PREFIX .. key .. " 必须是有限正整数。"
    end
    limits[key] = value
  end
  return limits
end

--- 只描述超限原因；进程是否退出、旧结果是否保留由调用边界分别报告。
function M.failure_message(metric, observed, limit)
  local label = metric
  for _, entry in ipairs(METRICS) do
    if entry[1] == metric then label = entry[3]; break end
  end
  return string.format(
    "%s结果超出保护阈值：%s已达到 %.0f，上限 %.0f。",
    PREFIX, label, observed, limit
  )
end
M.format = M.failure_message

local function empty_stats()
  return { rows = 0, columns = 0, cells = 0, bytes = 0 }
end

local function exceeds(stats, limits)
  for _, entry in ipairs(METRICS) do
    local observed = stats[entry[1]] or 0
    if observed > limits[entry[2]] then
      return M.failure_message(entry[1], observed, limits[entry[2]])
    end
  end
end

--- 通用计数器接口。所有 check_* 均返回 ok, err, stats。
function M.check(stats, opts)
  local limits, err = M.normalize_budget(opts)
  if not limits then return false, err, stats end
  if type(stats) ~= "table" then
    return false, PREFIX .. "结果计数必须是表。", stats
  end
  for _, entry in ipairs(METRICS) do
    if stats[entry[1]] ~= nil and not integer(stats[entry[1]], 0) then
      return false, PREFIX .. "结果计数必须是有限非负整数。", stats
    end
  end
  err = exceeds(stats, limits)
  return err == nil, err, stats
end

local function malformed(message)
  return PREFIX .. "无法安全计量结果：" .. message .. "。"
end

local function scalar_bytes(value)
  if value == nil then return 0 end
  if type(value) == "string" then return #value end
  if type(value) == "boolean" then return value and 4 or 5 end
  if type(value) == "number" then return #tostring(value) end
  return nil, malformed("单元格只能包含文本、数字、布尔值或 NULL")
end

local function add_value(stats, limits, value)
  local bytes, err = scalar_bytes(value)
  if not bytes then return err end
  stats.bytes = stats.bytes + bytes
  if stats.bytes > limits.max_bytes then
    return M.failure_message("bytes", stats.bytes, limits.max_bytes)
  end
end

local function dimensions(stats, limits)
  stats.cells = stats.rows * stats.columns
  return exceeds(stats, limits)
end

-- 原始结果的全部列、全部行均计入；不使用分页、筛选或隐藏列信息。
local function scan_result(result, stats, limits)
  if type(result) ~= "table" then return malformed("结果必须是表") end
  local columns, rows = result.columns or EMPTY, result.rows or EMPTY
  if type(columns) ~= "table" or type(rows) ~= "table" then
    return malformed("rows 和 columns 必须是表")
  end
  stats.columns, stats.rows = #columns, #rows
  local err = dimensions(stats, limits)
  if err then return err end

  for index, name in pairs(columns) do
    if not integer(index, 1) then return malformed("列必须使用正整数索引") end
    if type(name) ~= "string" then return malformed("列名必须是文本") end
    stats.columns = math.max(stats.columns, index)
    err = dimensions(stats, limits) or add_value(stats, limits, name)
    if err then return err end
  end
  for row_idx, row in pairs(rows) do
    if not integer(row_idx, 1) or type(row) ~= "table" then
      return malformed("原始行必须是二维数组")
    end
    stats.rows = math.max(stats.rows, row_idx)
    err = dimensions(stats, limits)
    if err then return err end
    for col_idx, value in pairs(row) do
      if not integer(col_idx, 1) then return malformed("原始单元格必须使用正整数索引") end
      -- 元数据缺列时也不能漏计真实存在的宽行。
      stats.columns = math.max(stats.columns, col_idx)
      err = dimensions(stats, limits) or add_value(stats, limits, value)
      if err then return err end
    end
  end
end

function M.check_result(result, opts)
  local stats = empty_stats()
  local limits, err = M.normalize_budget(opts)
  if limits then err = scan_result(result, stats, limits) end
  return err == nil, err, stats
end

local function scan_state(state, stats, limits, additional_rows, edit)
  local err = scan_result(state, stats, limits)
  if err then return err end
  local inserted, changes = state.inserted or EMPTY, state.changes or EMPTY
  if type(inserted) ~= "table" or type(changes) ~= "table" then
    return malformed("inserted 和 changes 必须是表")
  end

  -- 只建立最多 max_columns 项的列名集合，避免构造有效行或复制整个 state。
  local fields = {}
  for _, name in pairs(state.columns or EMPTY) do fields[name] = true end

  local function scan_values(values, row_idx, is_insert)
    if type(values) ~= "table" then return malformed("暂存值必须是列名到值的映射") end
    for field, value in pairs(values) do
      if not fields[field] then return malformed("暂存值包含结果之外的列") end
      local replaced = edit and edit.row_idx == row_idx and edit.field == field
        and edit.is_insert == is_insert
      if not replaced then
        local value_err = add_value(stats, limits, value)
        if value_err then return value_err end
      end
    end
  end

  for row_idx, row in pairs(inserted) do
    if type(row) ~= "table" then return malformed("暂存插入行缺少 values") end
    stats.rows = stats.rows + 1
    err = dimensions(stats, limits) or scan_values(row.values, row_idx, true)
    if err then return err end
  end
  -- 被标记删除的原始行仍驻留内存；deleted 不能抵扣 rows、cells 或 bytes。
  for row_idx, values in pairs(changes) do
    if not (state.rows or EMPTY)[row_idx] then return malformed("暂存修改没有对应原始行") end
    err = scan_values(values, row_idx, false)
    if err then return err end
  end

  if additional_rows ~= nil then
    if type(additional_rows) ~= "table" then return malformed("新增行必须是数组") end
    for _, values in pairs(additional_rows) do
      stats.rows = stats.rows + 1
      err = dimensions(stats, limits) or scan_values(values, nil, true)
      if err then return err end
    end
  end

  if edit then
    if not fields[edit.field] then return malformed("修改列不在原始结果中") end
    if not edit.is_insert and not (state.rows or EMPTY)[edit.row_idx] then
      return malformed("修改行不存在")
    end
    -- 与 data.add_change 一致：nil / "" 暂存为显式 NULL 哨兵。
    local value = edit.value
    if value == nil or value == "" then value = "\0NULL\0" end
    err = add_value(stats, limits, value)
  end
  return err
end

local function check_state(state, opts, additional_rows, edit)
  local stats = empty_stats()
  local limits, err = M.normalize_budget(opts)
  if limits then err = scan_state(state, stats, limits, additional_rows, edit) end
  return err == nil, err, stats
end

--- cells 是逻辑网格槽位；changes 不增加格数，但旧值和暂存新值均计 bytes。
function M.check_state(state, opts)
  return check_state(state, opts)
end

--- 在 insert_rows_with_values 深复制暂存树之前检查，不创建候选 state。
function M.check_insert(state, additional_rows, opts)
  return check_state(state, opts, additional_rows)
end

--- 在 add_change 深复制暂存树之前检查；替换已有暂存值时不重复累计旧暂存值。
function M.check_change(state, row_idx, field, value, opts)
  local edit = {
    row_idx = row_idx,
    field = field,
    value = value,
    is_insert = type(state) == "table" and type(state.inserted) == "table"
      and state.inserted[row_idx] ~= nil,
  }
  return check_state(state, opts, nil, edit)
end

local function import_dimensions(stats, limits)
  stats.cells = stats.rows * stats.columns
  for _, entry in ipairs(METRICS) do
    local observed = stats[entry[1]]
    if observed > limits[entry[2]] then
      local label = entry[1] == "rows" and "待解析记录数" or ("待解析" .. entry[3])
      return M.failure_message(label, observed, limits[entry[2]])
    end
  end
end

-- 与 importer 的分隔符选择一致。只保存计数和引号状态，不生成字段/行数组。
-- 空记录即使随后被 parse_csv 过滤，也已经会分配 all_rows，故计入解析预算。
local function scan_delimited(raw, offset, stats, limits)
  local header_end = raw:find("[\r\n]", offset) or (#raw + 1)
  local tab = raw:find("\t", offset, true)
  local delimiter = tab and tab < header_end and 9 or 44
  local separators = delimiter == 9 and "[\t\r\n]" or "[,\r\n]"
  local pos, records, fields = offset, 0, 1
  local field_start, quoted, after_quote, present = true, false, false, false

  local function check_fields()
    stats.columns = math.max(stats.columns, fields)
    return import_dimensions(stats, limits)
  end
  local function finish_record()
    records = records + 1
    stats.rows = math.max(0, records - 1) -- 首条结构记录作为表头预算。
    local err = check_fields()
    fields, field_start, after_quote, present = 1, true, false, false
    return err
  end

  while pos <= #raw do
    if quoted then
      local close = raw:find('"', pos, true)
      if not close then return malformed("CSV 引号未闭合") end
      if raw:byte(close + 1) == 34 then
        pos = close + 2 -- CSV "" 为字段内的一个引号。
      else
        pos, quoted, after_quote = close + 1, false, true
      end
    else
      local byte = raw:byte(pos)
      if byte == delimiter then
        fields, field_start, after_quote, present = fields + 1, true, false, true
        local err = check_fields()
        if err then return err end
        pos = pos + 1
      elseif byte == 10 or byte == 13 then
        local err = finish_record()
        if err then return err end
        if byte == 13 and raw:byte(pos + 1) == 10 then pos = pos + 1 end
        pos = pos + 1
      elseif after_quote then
        return malformed("CSV 引号后存在非分隔符")
      elseif byte == 34 and field_start then
        quoted, field_start, present, pos = true, false, true, pos + 1
      else
        field_start, present = false, true
        pos = raw:find(separators, pos) or (#raw + 1)
      end
    end
  end
  if quoted then return malformed("CSV 引号未闭合") end
  if present then return finish_record() end
end

-- 仅检查 JSON 结构预算；完整语法、键和值的解码仍由 vim.json.decode 负责。
-- 栈最多 64 项；容器计数拦截一行里嵌套数百万个 {}，不构造解码树。
local function scan_json(raw, offset, stats, limits)
  local top_array = raw:byte(offset) == 91
  local pos, depth, nodes = offset, 0, 0
  local stack = {}
  local expect_top, root_started, row_depth, row_fields = true, false, nil, 0
  local max_nodes = math.max(1024, limits.max_cells + limits.max_rows + 1)

  while pos <= #raw do
    local byte = raw:byte(pos)
    if byte == 32 or byte == 9 or byte == 10 or byte == 13 then
      pos = pos + 1
    else
      if top_array and depth == 1 and expect_top and byte ~= 93 and byte ~= 44 then
        stats.rows, expect_top = stats.rows + 1, false
        local err = import_dimensions(stats, limits)
        if err then return err end
      elseif not top_array and not root_started then
        stats.rows, root_started = 1, true
      end

      if byte == 34 then
        -- 偶数个反斜杠后的引号才结束字符串；字符串内括号、逗号不计结构。
        local search = pos + 1
        while true do
          local close = raw:find('"', search, true)
          if not close then return malformed("JSON 字符串未闭合") end
          local slash = close - 1
          while raw:byte(slash) == 92 do slash = slash - 1 end
          if (close - 1 - slash) % 2 == 0 then pos = close + 1; break end
          search = close + 1
        end
      else
        if byte == 123 or byte == 91 then
          if byte == 123 and ((top_array and depth == 1) or (not top_array and depth == 0)) then
            row_depth, row_fields = depth + 1, 0
          end
          depth, nodes = depth + 1, nodes + 1
          if depth > 64 then return M.failure_message("JSON 嵌套层数", depth, 64) end
          if nodes > max_nodes then return M.failure_message("JSON 容器数", nodes, max_nodes) end
          stack[depth] = byte
        elseif byte == 125 or byte == 93 then
          local expected = byte == 125 and 123 or 91
          if stack[depth] ~= expected then return malformed("JSON 括号不匹配") end
          if depth == row_depth then row_depth = nil end
          stack[depth], depth = nil, depth - 1
        elseif byte == 58 and depth == row_depth then
          row_fields = row_fields + 1
          stats.columns = math.max(stats.columns, row_fields)
          local err = import_dimensions(stats, limits)
          if err then return err end
        elseif byte == 44 and top_array and depth == 1 then
          expect_top = true
        end
        pos = pos + 1
      end
    end
  end
  if depth ~= 0 then return malformed("JSON 括号未闭合") end
  return import_dimensions(stats, limits)
end

--- 导入前按原始字节与待解析结构预检；完整解析后仍须 check_insert。
function M.check_import(raw, opts)
  local stats = empty_stats()
  if type(raw) ~= "string" then
    return false, malformed("导入内容必须是文本"), stats
  end
  local limits, err = M.normalize_budget(opts)
  if not limits then return false, err, stats end
  stats.bytes = #raw
  err = exceeds(stats, limits)
  if err then return false, err, stats end

  local offset = raw:sub(1, 3) == "\239\187\191" and 4 or 1
  local first = raw:find("%S", offset)
  if first then
    local byte = raw:byte(first)
    if byte == 91 or byte == 123 then
      err = scan_json(raw, first, stats, limits)
    else
      err = scan_delimited(raw, offset, stats, limits)
    end
  end
  return err == nil, err, stats
end

return M
