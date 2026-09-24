vim.opt.runtimepath:prepend(vim.fn.getcwd())

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)

local observed_sql
local observed_page_info
local fake_view = { _sessions = {} }
fake_view.open = function(state, _, _, opts)
  fake_view._sessions[bufnr] = {
    state = state,
    query_spec = opts.query_spec,
    total_rows = opts.total_rows,
  }
  return bufnr
end
fake_view.render = function() end
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

package.loaded["dadbod-grip.db"] = {
  is_readonly = function() return false end,
  get_primary_keys = function(table_name)
    if table_name == "base_sms_person_module" then return { "id" } end
    return {}
  end,
}

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
    local state = {
      columns = { "id", "name" },
      rows = {
        { "1", "Alice" },
        { "2", "Bob" },
        { "3", "Carol" },
      },
      pks = {},
      table_name = nil,
      readonly = true,
    }
    if fake_view.open then
      fake_view.open(state, "mysql://test", cleaned, { query_spec = spec })
    end
    fake_view._sessions[bufnr] = fake_view._sessions[bufnr] or {
      state = state,
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

local infer = runner._infer_editable_table
local cte_sql = [[
WITH role_id AS (
  SELECT id
  FROM base_sms_person
  WHERE phone = '13564546121'
)
SELECT *
FROM base_sms_person_module
WHERE record_id IN (SELECT id FROM role_id)
  AND module_name = '异常数据';
]]
assert(infer(cte_sql) == "base_sms_person_module",
  "CTE must infer the real table used by the outer SELECT")
assert(infer([[WITH x AS (SELECT * FROM people) SELECT * FROM x]]) == nil,
  "selecting from a CTE result must remain read-only")
assert(infer([[WITH x AS (SELECT 1) SELECT * FROM people p JOIN roles r ON r.id = p.role_id]]) == nil,
  "JOIN results must remain read-only")
assert(infer([[SELECT * FROM people UNION SELECT * FROM archived_people]]) == nil,
  "set-operation results must remain read-only")

fake_view._sessions[bufnr] = nil
local cte_ok, cte_err = runner._open_exact_query(cte_sql, "mysql://test", {})
assert(cte_ok, cte_err)
local cte_session = fake_view._sessions[bufnr]
assert(cte_session.state.table_name == "base_sms_person_module",
  "CTE result must carry the inferred editable table")
assert(cte_session.state.readonly == false, "CTE result with a primary key must be editable")
assert(vim.deep_equal(cte_session.state.pks, { "id" }), "CTE result must carry primary keys")

print("PASS: SQL runner exact query and CTE editability")
