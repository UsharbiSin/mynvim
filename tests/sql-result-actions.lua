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

local browser = require("config.sql-browser")
browser.setup()
vim.api.nvim_exec_autocmds("BufEnter", { buffer = bufnr })
vim.wait(1000, function()
  return vim.fn.maparg("<leader>sx", "n", false, true).buffer == 1
end)
assert(
  vim.fn.maparg("<leader>sx", "n", false, true).desc == "SQL：导出当前结果页为 XLSX 或 CSV",
  "result grid must expose the export mapping"
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

print("PASS: SQL result column actions")
