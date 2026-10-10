-- nvim --headless -u NONE -i NONE -l tests/sql-result-budget.lua
-- 纯预算测试，不加载数据库插件、不读取凭据、不启动外部数据库进程。
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local budget = require("config.sql-result-budget")
local checks = 0
local function check(condition, message)
  assert(condition, message)
  checks = checks + 1
end
local function accepted(callback, message)
  local ok, err, stats = callback()
  check(ok and err == nil, message .. ": " .. tostring(err))
  return stats
end
local function rejected(callback, text, message)
  local ok, err, stats = callback()
  check(not ok and type(err) == "string", message)
  check(err:find("[SQL_RESULT_GUARD]", 1, true) == 1, "failures must share a stable prefix")
  check(err:find(text, 1, true) ~= nil, message .. ": " .. err)
  return stats
end

-- 统一默认值、参数验证以及独立配置表。
local defaults = assert(budget.normalize_budget())
check(defaults.max_rows == 10000 and defaults.max_cells == 200000, "row/cell defaults")
check(defaults.max_columns == 256 and defaults.max_bytes == 16 * 1024 * 1024, "column/byte defaults")
check(defaults.max_stderr_bytes == 65536, "stderr must share the same defaults")
local opts = { max_rows = 2 }
local normalized = assert(budget.normalize_budget(opts))
normalized.max_rows = 3
check(opts.max_rows == 2 and budget.DEFAULTS.max_rows == 10000, "normalization must not mutate inputs/defaults")
for _, invalid in ipairs({ 0, -1, 0.5, math.huge, -math.huge, 0 / 0, "100", false }) do
  local limits, err = budget.normalize_budget({ max_rows = invalid })
  check(limits == nil and err:find("有限正整数", 1, true) ~= nil, "invalid budgets must fail closed")
end
check(budget.normalize_budget({ max_row = 10 }) == nil, "misspelled limits must not silently use defaults")
check(budget.normalize_budget("unlimited") == nil, "non-table options must be rejected")
for _, invalid in ipairs({ -1, 0.5, math.huge, 0 / 0, "1" }) do
  rejected(function() return budget.check({ rows = invalid }) end, "非负整数", "invalid counters")
end
accepted(function() return budget.check({ rows = 0, cells = 0, columns = 0, bytes = 0 }) end, "empty counters")

-- 四个默认边界使用计数器直接验证，避免测试自身分配巨型结果。
local metrics = { rows = "max_rows", cells = "max_cells", columns = "max_columns", bytes = "max_bytes" }
for metric, key in pairs(metrics) do
  accepted(function() return budget.check({ [metric] = defaults[key] }) end, "exact " .. metric .. " boundary")
  rejected(function() return budget.check({ [metric] = defaults[key] + 1 }) end,
    "超出保护阈值", "one over " .. metric .. " boundary")
end

-- 原始结果按真实 UTF-8 字节计量，不用字符数，不把元数据里的总行数算作已加载行。
local result = {
  columns = { "a", "b" },
  rows = { { "1", "22" }, { "333", "4" } },
  total_rows = 999999999,
}
local stats = accepted(function()
  return budget.check_result(result, { max_rows = 2, max_columns = 2, max_cells = 4, max_bytes = 9 })
end, "exact result limits")
check(stats.rows == 2 and stats.columns == 2 and stats.cells == 4 and stats.bytes == 9,
  "result statistics must describe actual loaded content")
rejected(function() return budget.check_result(result, { max_rows = 1 }) end, "数据行数", "raw rows")
rejected(function() return budget.check_result(result, { max_cells = 3 }) end, "单元格数", "raw cells")
rejected(function() return budget.check_result(result, { max_columns = 1 }) end, "列数", "raw columns")
rejected(function() return budget.check_result(result, { max_bytes = 8 }) end, "字节", "raw bytes")
accepted(function()
  return budget.check_result({ columns = { "值" }, rows = { { "深" } } }, { max_bytes = 6 })
end, "UTF-8 bytes exactly fit")
rejected(function()
  return budget.check_result({ columns = { "值" }, rows = { { "深" } } }, { max_bytes = 5 })
end, "字节", "UTF-8 bytes must not be counted as characters")
stats = accepted(function()
  return budget.check_result({ columns = { "a" }, rows = { { "1", "2" }, {} } })
end, "ragged rows must not conceal extra columns")
check(stats.columns == 2 and stats.cells == 4, "missing and extra cells must still reserve all logical grid slots")
rejected(function()
  return budget.check_result({ columns = { "a" }, rows = { { "1", "2" } } }, { max_columns = 1 })
end, "列数", "row width wider than metadata")

-- state 使用真实的 inserted[row_idx].values 结构；原始删除行、隐藏列仍占预算。
local state = {
  columns = { "id", "name" },
  rows = { { "1", "old" } },
  inserted = { [1001] = { _after = 1, values = { id = "2", name = "new" } } },
  changes = { [1] = { name = "changed" } },
  deleted = { [1] = true },
  visible_columns = { "id" },
  filtered_rows = {},
}
local before = vim.deepcopy(state)
stats = accepted(function()
  return budget.check_state(state, { max_rows = 2, max_cells = 4, max_columns = 2, max_bytes = 21 })
end, "exact state limits")
check(stats.rows == 2 and stats.cells == 4 and stats.columns == 2 and stats.bytes == 21,
  "state bytes include column names, original data, inserts and staged changes")
rejected(function() return budget.check_state(state, { max_rows = 1 }) end, "数据行数", "deleted original rows still count")
rejected(function() return budget.check_state(state, { max_columns = 1 }) end, "列数", "hidden columns still count")
rejected(function() return budget.check_state(state, { max_bytes = 20 }) end, "字节", "staged edits still use bytes")
stats = accepted(function()
  return budget.check_state({
    columns = { "a" }, rows = { { "a" } }, changes = { [1] = { a = "b" } },
  }, { max_cells = 1, max_bytes = 3 })
end, "a grid at its cell limit remains editable")
check(stats.cells == 1 and stats.bytes == 3, "changes add retained bytes, not logical grid cells")

-- 在真正执行插入或修改、深复制、写 undo 之前计量候选操作。
local additional = { { name = "x" } }
local extra_before = vim.deepcopy(additional)
rejected(function() return budget.check_insert(state, additional, { max_rows = 2 }) end,
  "数据行数", "pending inserts must be rejected before allocation")
rejected(function() return budget.check_insert(state, additional, { max_cells = 5 }) end,
  "单元格数", "inserted rows use all columns, including blank fields")
stats = accepted(function()
  return budget.check_insert(state, additional, { max_rows = 3, max_cells = 6, max_bytes = 22 })
end, "exact additional insert limits")
check(stats.rows == 3 and stats.cells == 6 and stats.bytes == 22, "candidate insert statistics")
stats = accepted(function() return budget.check_insert(state, { {} }, { max_cells = 6 }) end,
  "blank inserted rows still reserve their columns")
check(stats.rows == 3 and stats.cells == 6 and stats.bytes == 21, "blank insert counters")

stats = accepted(function() return budget.check_change(state, 1, "name", "value", { max_bytes = 19 }) end,
  "replacing a staged edit must not retain its previous staged value in the new state budget")
check(stats.bytes == 19 and stats.cells == 4, "replacement edit counters")
stats = accepted(function() return budget.check_change(state, 1001, "name", "Y", { max_bytes = 19 }) end,
  "editing an inserted row must replace inserted.values")
check(stats.bytes == 19, "inserted edit counters")
stats = accepted(function() return budget.check_change(state, 1, "name", nil, { max_bytes = 20 }) end,
  "explicit NULL must account for the real NULL sentinel")
check(stats.bytes == 20, "NULL sentinel bytes")
rejected(function() return budget.check_change(state, 1, "name", string.rep("z", 20), { max_bytes = 21 }) end,
  "字节", "long staged values cannot bypass raw result limits")
rejected(function() return budget.check_change(state, 1, "absent", "x") end, "修改列", "unknown edit field")
rejected(function() return budget.check_change(state, 999, "name", "x") end, "修改行", "unknown edit row")
check(vim.deep_equal(state, before) and vim.deep_equal(additional, extra_before),
  "budget checks must leave state, pending edits and input rows untouched")

-- 导入在分配解析树之前按原始字节和结构检查；引号内换行不是新记录。
local raw = 'name\n"first\nsecond"\n'
stats = accepted(function() return budget.check_import(raw, { max_bytes = #raw }) end, "exact import bytes")
check(stats.rows == 1 and stats.cells == 1 and stats.bytes == #raw, "quoted newline must remain in one import record")
rejected(function() return budget.check_import(raw, { max_bytes = #raw - 1 }) end, "字节", "import one byte over")
rejected(function() return budget.check_import(string.rep("x", 1025), { max_bytes = 1024 }) end,
  "字节", "an unterminated long line must be rejected without waiting for a newline")
rejected(function() return budget.check_import({ raw }) end, "文本", "import input type")

-- CSV / TSV 必须在 parse_csv 分配 all_rows 之前识别过量的逻辑记录。
local csv = 'a,b\r\n"first\nline","a""b"\r\nsecond,last'
stats = accepted(function()
  return budget.check_import(csv, { max_rows = 2, max_columns = 2, max_cells = 4 })
end, "CSV quoting, escaped quotes and CRLF")
check(stats.rows == 2 and stats.columns == 2 and stats.cells == 4, "CSV structural counts")
rejected(function() return budget.check_import(csv, { max_rows = 1 }) end,
  "待解析记录数", "CSV row limit before allocation")
rejected(function() return budget.check_import(csv, { max_cells = 3 }) end,
  "单元格数", "CSV cell limit before allocation")
rejected(function() return budget.check_import("a,b,c\n1,2,3", { max_columns = 2 }) end,
  "列数", "CSV header width before allocation")
rejected(function() return budget.check_import('a\n""\n""\n""\n', { max_rows = 2 }) end,
  "待解析记录数", "filtered empty records still allocate parser rows")
rejected(function() return budget.check_import("a\n\n\n\n", { max_rows = 2 }) end,
  "待解析记录数", "blank records still allocate parser rows")
stats = accepted(function() return budget.check_import('a\tb\n"x\ty"\t"line\nnext"') end,
  "quoted TSV delimiters and line breaks")
check(stats.rows == 1 and stats.columns == 2, "TSV structure")
stats = accepted(function() return budget.check_import("\239\187\191" .. csv) end, "UTF-8 BOM handling")
check(stats.rows == 2 and stats.columns == 2, "BOM must not affect format detection")
rejected(function() return budget.check_import('a\n"unterminated') end,
  "CSV 引号", "unterminated CSV quote must not conceal subsequent records")

-- JSON 扫描只计结构，不解码：字符串内的逗号、括号和转义引号不增加行列。
local json = [=[ [{"name":"quote \", brace }, comma , and \\ slash"},{"name":"next"}] ]=]
stats = accepted(function()
  return budget.check_import(json, { max_rows = 2, max_columns = 1, max_cells = 2 })
end, "JSON escaped strings")
check(stats.rows == 2 and stats.columns == 1 and stats.cells == 2, "JSON structural counts")
rejected(function() return budget.check_import("[{},{},{}]", { max_rows = 2 }) end,
  "待解析记录数", "JSON objects limited before vim.json.decode")
rejected(function() return budget.check_import('[{"a":1,"b":2,"c":3}]', { max_columns = 2 }) end,
  "列数", "JSON fields limited before decode")
rejected(function() return budget.check_import('[{"a":1,"b":2},{"a":3,"b":4}]', { max_cells = 3 }) end,
  "单元格数", "JSON cell limit before decode")
stats = accepted(function() return budget.check_import('{"a":{"nested":[1,2]},"b":"\\""}') end,
  "single object and nested values")
check(stats.rows == 1 and stats.columns == 2, "only direct fields of an imported row count as columns")
local nested_ok = '[{"a":' .. string.rep("[", 62) .. "0" .. string.rep("]", 62) .. "}]"
accepted(function() return budget.check_import(nested_ok) end, "JSON depth 64")
local nested_bad = '[{"a":' .. string.rep("[", 63) .. "0" .. string.rep("]", 63) .. "}]"
rejected(function() return budget.check_import(nested_bad) end, "嵌套层数", "JSON depth must be bounded before decode")
local many_nodes = '[{"a":[' .. string.rep("{},", 1022) .. "{}]}]"
rejected(function() return budget.check_import(many_nodes, { max_rows = 1, max_cells = 1 }) end,
  "容器数", "many nested objects in one cell must not create an unbounded decode tree")

-- 不支持的嵌套内容必须明确拒绝，不能 tostring 整个对象或让计量器触发异常。
rejected(function() return budget.check_result({ columns = { {} }, rows = {} }) end, "列名", "malformed headers")
rejected(function() return budget.check_result({ columns = { "a" }, rows = { { {} } } }) end,
  "单元格", "nested cell objects")
rejected(function() return budget.check_state({ columns = { "a" }, rows = {}, inserted = { [1] = {} } }) end,
  "暂存值", "insert wrapper shape")
rejected(function() return budget.check_state(nil) end, "结果必须是表", "invalid state")
check(package.loaded["dadbod-grip"] == nil, "pure checks must not load the database plugin")

print(string.format("sql-result-budget: %d checks passed", checks))
