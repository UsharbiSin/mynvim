local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)

local session = {
  state = {
    columns = { "id", "name", "created_at" },
    rows = {
      { "1", "Alice", "2026-09-08" },
    },
  },
  _render = {
    visible_columns = { "id", "name", "created_at" },
  },
  query_spec = {
    sorts = {},
    filters = {},
    page = 3,
  },
}

local fake_view = {
  _sessions = { [bufnr] = session },
  _resolve_col_at = function()
    return "name"
  end,
  get_cell = function()
    return { row_idx = 1 }
  end,
  render = function(_, state)
    session.state = state
    session._render = {
      visible_columns = vim.deepcopy(state.columns),
      hdr_byte_positions = {
        name = { start = 1, finish = 4 },
      },
      data_start = 4,
      byte_positions = {},
    }
  end,
}
package.loaded["dadbod-grip.view"] = fake_view
local fake_data = {
  has_changes = function() return false end,
  count_staged = function() return 0 end,
  get_ordered_rows = function(state)
    local rows = {}
    for index = 1, #state.rows do rows[#rows + 1] = index end
    for index in pairs(state.inserted or {}) do rows[#rows + 1] = index end
    return rows
  end,
  effective_value = function(state, row_index, column)
    if state.inserted and state.inserted[row_index] then
      return state.inserted[row_index].values[column]
    end
    if state.changes and state.changes[row_index] and state.changes[row_index][column] ~= nil then
      return state.changes[row_index][column]
    end
    for index, name in ipairs(state.columns) do
      if name == column then return state.rows[row_index][index] end
    end
  end,
}
package.loaded["dadbod-grip.data"] = fake_data
package.loaded["dadbod-grip.sql"] = {
  quote_ident = function(name)
    return '"' .. tostring(name):gsub('"', '""') .. '"'
  end,
}
package.loaded["dadbod-grip.query"] = {
  add_filter = function(spec, clause)
    local next_spec = vim.deepcopy(spec)
    next_spec.filters = next_spec.filters or {}
    next_spec.filters[#next_spec.filters + 1] = { clause = clause }
    next_spec.page = 1
    return next_spec
  end,
  build_sql = function(spec)
    local parts = { "SELECT * FROM (" .. spec.base_sql .. ") AS _grip" }
    if #(spec.filters or {}) > 0 then
      local clauses = {}
      for _, filter in ipairs(spec.filters) do clauses[#clauses + 1] = "(" .. filter.clause .. ")" end
      parts[#parts + 1] = "WHERE " .. table.concat(clauses, " AND ")
    end
    parts[#parts + 1] = "LIMIT " .. spec.page_size
    return table.concat(parts, " ")
  end,
  build_count_sql = function(spec)
    local sql = "SELECT COUNT(*) AS _grip_count FROM (" .. spec.base_sql .. ") AS _grip"
    if #(spec.filters or {}) > 0 then
      local clauses = {}
      for _, filter in ipairs(spec.filters) do clauses[#clauses + 1] = "(" .. filter.clause .. ")" end
      sql = sql .. " WHERE " .. table.concat(clauses, " AND ")
    end
    return sql
  end,
}

local browser = require("config.sql-browser")
browser.setup()
assert(vim.deep_equal(browser._result_query_lines({
  query_sql = "SELECT id, name\nFROM people\nWHERE active = 1",
}), {
  " 查询 SQL：",
  "SELECT id, name",
  "FROM people",
  "WHERE active = 1",
}), "result grid footer must preserve the SQL text and line breaks")
assert(vim.deep_equal(browser._result_query_lines({ query_sql = "   " }), {}),
  "blank SQL must not add an empty query footer")
vim.api.nvim_exec_autocmds("BufEnter", { buffer = bufnr })
vim.wait(1000, function()
  return vim.fn.maparg("<leader>sx", "n", false, true).buffer == 1
end)
assert(
  vim.fn.maparg("<leader>sx", "n", false, true).desc == "SQL：导出当前结果页为 XLSX 或 CSV",
  "result grid must expose the export mapping"
)
assert(
  vim.fn.maparg("/", "n", false, true).desc == "SQL：按当前列输入 WHERE 条件筛选",
  "result grid must map / to the current-column WHERE filter"
)
assert(
  vim.fn.maparg("|", "n", false, true).desc == "SQL：切换当前筛选或新筛选的 AND/OR 连接方式",
  "result grid must map | to the filter join toggle"
)
assert(
  vim.fn.maparg("d", "n", false, true).desc == "SQL：删除当前筛选条件或数据行",
  "result grid must make d context-sensitive for filters and rows"
)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
browser.reorder_result_column(-1)
assert(vim.deep_equal(
  session.state.columns,
  { "name", "id", "created_at" }
))

assert(vim.deep_equal(
  session.state.rows,
  {
    { "Alice", "1", "2026-09-08" },
  }
))

assert(vim.deep_equal(session.state.columns, { "name", "id", "created_at" }))

browser.reorder_result_column(1)
assert(vim.deep_equal(session.state.columns, { "id", "name", "created_at" }))
browser.reorder_result_column(-1)
assert(vim.deep_equal(session.state.columns, { "name", "id", "created_at" }))

assert(vim.deep_equal(
  browser._merge_column_order({ "name", "id" }, { "id", "status", "name" }),
  { "name", "id", "status" }
))

local sorted
session.on_requery = function(_, spec)
  sorted = spec

  session.state = {
    columns = { "id", "name", "created_at" },
    rows = {
      { "1", "Alice", "2026-09-08" },
    },
  }
end
browser.sort_result_column("ASC")

assert(vim.deep_equal(
  session.state.columns,
  { "name", "id", "created_at" }
))

assert(vim.deep_equal(
  session.state.rows,
  {
    { "Alice", "1", "2026-09-08" },
  }
))
assert(sorted.sorts[1].column == "name" and sorted.sorts[1].dir == "ASC")
assert(sorted.page == 1)
assert(vim.deep_equal(session.state.columns, { "name", "id", "created_at" }))
browser.sort_result_column("DESC")
assert(sorted.sorts[1].column == "name" and sorted.sorts[1].dir == "DESC")
assert(vim.deep_equal(session.state.columns, { "name", "id", "created_at" }))

assert(vim.deep_equal(browser._next_sorts({}, "name", "ASC"), {
  { column = "name", dir = "ASC" },
}))
assert(vim.deep_equal(browser._next_sorts({
  { column = "name", dir = "ASC" },
}, "name", "ASC"), {}), "same direction must cancel the column sort")
assert(vim.deep_equal(browser._next_sorts({
  { column = "name", dir = "ASC" },
}, "name", "DESC"), {
  { column = "name", dir = "DESC" },
}), "opposite direction must replace the column sort")
assert(vim.deep_equal(browser._next_sorts({
  { column = "name", dir = "ASC" },
}, "id", "DESC"), {
  { column = "name", dir = "ASC" },
  { column = "id", dir = "DESC" },
}), "a second column must preserve multi-column sort priority")

assert(
  browser._build_column_where_clause("name", " LIKE '%Ali%' ") == '"name" LIKE \'%Ali%\'',
  "column WHERE builder must prefix the current quoted column and trim the condition"
)
assert(browser._build_column_where_clause("name", "   ") == nil, "blank filters must be ignored")

local filter_prompt
local filtered
local original_input = vim.ui.input
vim.ui.input = function(opts, callback)
  filter_prompt = opts.prompt
  callback("LIKE '%Ali%'")
end
session.query_spec = {
  sorts = {},
  filters = {},
  page = 3,
}
session.on_requery = function(_, spec)
  filtered = spec
  session.query_spec = spec
  session.state = {
    columns = { "id", "name", "created_at" },
    rows = {
      { "1", "Alice", "2026-09-08" },
    },
  }
end
browser.filter_result_column()
vim.ui.input = original_input

assert(filter_prompt == 'WHERE "name"  [AND] ', "filter prompt must identify the current column and join mode")
assert(filtered.page == 1, "filtering must return to the first page")
assert(filtered.filters[1].clause == '"name" LIKE \'%Ali%\'', "filter must target the current column")
assert(filtered.filters[1].join == "AND", "new filters must record the active join mode")
assert(vim.deep_equal(
  session.state.columns,
  { "name", "id", "created_at" }
), "filter requery must preserve the manually reordered columns")

local joined_spec = {
  is_raw = true,
  base_sql = "SELECT * FROM people",
  filters = {
    { clause = '"id" = 1', join = "AND" },
    { clause = '"name" = \'Alice\'', join = "OR" },
    { clause = '"active" = 1', join = "AND" },
  },
  sorts = {},
  page = 1,
  page_size = 100,
}
assert(
  browser._joined_where_clause(joined_spec)
    == 'WHERE ((("id" = 1) OR ("name" = \'Alice\')) AND ("active" = 1))',
  "mixed AND/OR filters must be grouped in input order"
)
local joined_sql = package.loaded["dadbod-grip.query"].build_sql(joined_spec)
assert(
  joined_sql
    == 'SELECT * FROM (SELECT * FROM people) AS _grip WHERE (((("id" = 1) OR ("name" = \'Alice\')) AND ("active" = 1))) LIMIT 100',
  "query builder must use the stored filter joins"
)

browser.toggle_filter_join_mode()
local or_prompt
vim.ui.input = function(opts, callback)
  or_prompt = opts.prompt
  callback("LIKE '%Bob%'")
end
session.on_requery = function(_, spec)
  filtered = spec
  session.query_spec = spec
  session.state = {
    columns = { "id", "name", "created_at" },
    rows = { { "2", "Bob", "2026-09-09" } },
  }
end
browser.filter_result_column()
vim.ui.input = original_input
assert(or_prompt == 'WHERE "name"  [OR] ', "| must switch the next filter to OR")
assert(filtered.filters[#filtered.filters].join == "OR", "OR mode must be stored on the appended filter")

session.query_spec = {
  sorts = {},
  filters = {
    { clause = '"id" LIKE \'%0%\'', join = "AND" },
    { clause = '"name" LIKE \'%Bob%\'', join = "OR" },
  },
  page = 2,
}
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "status",
  ' ▾ "id" LIKE \'%0%\'',
  ' ▾ "name" LIKE \'%Bob%\'',
  "hint",
})
vim.api.nvim_win_set_cursor(0, { 3, 0 })

local toggled_filter_spec
session.on_requery = function(_, spec)
  toggled_filter_spec = spec
  session.query_spec = spec
  session.state = {
    columns = { "id", "name", "created_at" },
    rows = { { "2", "Bob", "2026-09-09" } },
  }
end
browser.toggle_filter_join_mode()
assert(toggled_filter_spec.filters[2].join == "AND", "| on a filter row must toggle that row from OR to AND")
assert(toggled_filter_spec.page == 1, "toggling a filter-row join must return to the first page")

local deleted_filter_spec
session.on_requery = function(_, spec)
  deleted_filter_spec = spec
  session.query_spec = spec
  session.state = {
    columns = { "id", "name", "created_at" },
    rows = { { "2", "Bob", "2026-09-09" } },
  }
end
assert(browser.delete_result_filter() == true, "d on a filter line must handle that filter")
assert(#deleted_filter_spec.filters == 1, "deleting a filter line must remove only that condition")
assert(deleted_filter_spec.filters[1].clause == '"id" LIKE \'%0%\'', "the other filter must remain")
assert(deleted_filter_spec.page == 1, "deleting a filter must return to the first page")

session.query_spec = { sorts = {}, filters = {}, page = 1 }
session.state.readonly = false
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "data" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
local deleted_row
session.on_delete = function(_, row_idx)
  deleted_row = row_idx
end
browser.delete_filter_or_row()
assert(deleted_row == 1, "d outside filter lines must retain the original row-delete behavior")

local stable_state = session.state
local stable_spec = {
  sorts = { { column = "created_at", dir = "DESC" } },
  filters = { { clause = '"name" LIKE \'%Alice%\'' } },
  page = 2,
}
session.query_spec = vim.deepcopy(stable_spec)
session.query_sql = "previous valid sql"
session.total_rows = 321
vim.ui.input = function(_, callback)
  callback("LIKE")
end
session.on_requery = function(_, spec)
  -- 模拟 Dadbod Grip 当前失败路径：query_spec/query_sql/total_rows 已更新，
  -- 但 apply_refresh 因查询失败而不会替换 state。
  session.query_spec = spec
  session.query_sql = "invalid sql"
  session.total_rows = 0
end
browser.filter_result_column()
vim.ui.input = original_input

assert(session.state == stable_state, "failed filter must keep the previous result state")
assert(vim.deep_equal(session.query_spec, stable_spec), "failed filter must restore the previous query spec")
assert(session.query_sql == "previous valid sql", "failed filter must restore the previous query SQL")
assert(session.total_rows == 321, "failed filter must restore the previous row count")

assert(browser._resize_width(10, -20) == 6, "column width must have a lower bound")
assert(browser._resize_width(10, 4) == 14, "column width must grow by the requested amount")
assert(browser._resize_width(199, 4) == 200, "column width must have an upper bound")

local export_state = {
  columns = { "id", "name" },
  rows = { { "1", "Alice" }, { "2", "Bob" } },
  changes = { [1] = { name = "艾丽丝" } },
  deleted = { [2] = true },
  inserted = { [1003] = { values = { id = "3", name = "Carol" } } },
}
assert(vim.deep_equal(browser._export_rows(export_state), {
  { "1", "艾丽丝" },
  { "3", "Carol" },
}), "export must use effective values and omit staged deletions")

local export_null_state = {
  columns = { "id", "bidding_name", "project_region" },
  rows = { { "1", "", "浦东" } },
  changes = {},
  deleted = {},
  inserted = {},
}
local export_null_rows = browser._export_rows(export_null_state)
assert(#export_null_rows[1] == 3, "SQL NULL must not shorten an exported row")
assert(vim.deep_equal(export_null_rows[1], { "1", "", "浦东" }),
  "SQL NULL must export as an empty cell without shifting later columns")

assert(
  vim.fn.fnamemodify(browser._export_default_path({
    state = { table_name = "monitor.platform" },
    opts = { source_path = "C:/queries/Script.sql" },
  }, "xlsx"), ":t") == "monitor.platform.xlsx",
  "table results must use the database table name"
)
assert(
  vim.fn.fnamemodify(browser._export_default_path({
    state = {},
    query_spec = { is_raw = true },
    opts = { source_path = "C:/queries/巡检脚本.sql" },
  }, "csv"), ":t") == "巡检脚本.csv",
  "raw queries must use the source SQL file name"
)
assert(
  vim.fn.fnamemodify(browser._export_default_path({
    state = { table_name = 'bad:name*' },
  }, "csv"), ":t") == "bad_name_.csv",
  "export names must replace characters forbidden by Windows"
)

print("PASS: SQL result column actions")
