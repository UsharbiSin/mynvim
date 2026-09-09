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
package.loaded["dadbod-grip.data"] = {
  has_changes = function() return false end,
  count_staged = function() return 0 end,
}

local browser = require("config.sql-browser")
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

print("PASS: SQL result column actions")
