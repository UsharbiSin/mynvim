vim.opt.runtimepath:prepend(vim.fn.getcwd())

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)

local observed_sql
local observed_page_info
local fake_view = { _sessions = {} }
package.loaded["dadbod-grip.view"] = fake_view

local fake_query = {}
local original_build_sql = function(spec)
  return "SELECT * FROM (" .. spec.base_sql .. ") AS _grip LIMIT " .. spec.page_size
end
local original_page_info = function(spec, total_rows)
  return ("Page %d (%d rows)"):format(spec.page, total_rows or 0)
end
fake_query.build_sql = original_build_sql
fake_query.page_info = original_page_info
package.loaded["dadbod-grip.query"] = fake_query

package.loaded["dadbod-grip"] = {
  open = function(sql)
    local cleaned = sql:gsub(";%s*$", "")
    local spec = {
      base_sql = cleaned,
      filters = {},
      sorts = {},
      page = 1,
      page_size = 1000,
      is_raw = true,
    }
    observed_sql = fake_query.build_sql(spec)
    observed_page_info = fake_query.page_info(spec, 3)
    fake_view._sessions[bufnr] = {
      state = {
        rows = {
          { "1", "Alice" },
          { "2", "Bob" },
          { "3", "Carol" },
        },
      },
      query_spec = spec,
      total_rows = 3,
    }
  end,
}

local runner = require("config.sql-runner")
local ok, err = runner._open_exact_query("SELECT id, name FROM people;", "mysql://test", {})
assert(ok, err)
assert(observed_sql == "SELECT id, name FROM people",
  "<leader>sr must execute the original SELECT without an outer LIMIT wrapper")
assert(observed_page_info == "Page 1/1 (3 rows)",
  "an exact query must be rendered as one complete result set")
assert(fake_query.build_sql == original_build_sql, "query.build_sql must be restored after execution")
assert(fake_query.page_info == original_page_info, "query.page_info must be restored after execution")

local session = fake_view._sessions[bufnr]
assert(session.query_spec.page_size == 3, "result page size must match the rows actually returned")
assert(session.total_rows == 3, "result row count must match the rows actually returned")

print("PASS: SQL runner exact query")
