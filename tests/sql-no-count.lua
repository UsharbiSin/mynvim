-- 实际加载已安装的 Grip；仅替换数据库边界，不访问真实数据库或凭据。
-- nvim --headless -u NONE -i NONE --cmd 'set rtp+=/path/to/dadbod-grip.nvim' \
--   '+lua dofile("tests/sql-no-count.lua")' +qa!
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local grip = require("dadbod-grip")
local query = require("dadbod-grip.query")
local db = require("dadbod-grip.db")
local view = require("dadbod-grip.view")
local ui = require("dadbod-grip.ui")
local history = require("dadbod-grip.history")
local pad = require("dadbod-grip.query_pad")
local notifications, sql_log = {}, {}
local row_total, fail_query = 1505, false
local checks = 0
local function check(condition, message)
  assert(condition, message)
  checks = checks + 1
end

vim.notify = function(message) notifications[#notifications + 1] = message end
ui.blocking = function(_, callback) return callback() end
history.record = function() end
pad.sync_query = function() end
-- 留下防护：所有数据 SQL 必须经过下面的替身，不能意外启动客户端。
require("dadbod-grip.adapters").run_cmd = function() error("Unexpected database process") end
require("dadbod-grip.adapters").run_cmd_async = function() error("Unexpected async database process") end
db.is_readonly = function() return false end
db.get_primary_keys = function() return { "id" } end
db.get_column_info = function()
  return { { column_name = "id", data_type = "int", is_nullable = "NO", constraints = "PRIMARY KEY" } }
end
db.query = function(sql)
  check(type(sql) == "string", "private skip token must never reach the database adapter")
  sql_log[#sql_log + 1] = sql
  if fail_query then return nil, "simulated query failure" end
  if sql:match("^SELECT COUNT%(%*%)") then
    return { columns = { "_grip_count" }, rows = { { tostring(row_total) } }, primary_keys = {} }
  end
  local limit = tonumber(sql:match("LIMIT%s+(%d+)")) or row_total
  local offset = tonumber(sql:match("OFFSET%s+(%d+)")) or 0
  local rows = {}
  for i = offset + 1, math.min(row_total, offset + limit) do
    rows[#rows + 1] = { tostring(i) }
  end
  return { columns = { "id" }, rows = rows, primary_keys = {} }
end

grip.setup({ limit = 1000, ai = false, completion = false, discovery = false })
require("config.sql-browser").setup()
local no_count = require("config.sql-no-count")
no_count.install()
local wrapped_open = grip.open
no_count.install()
check(grip.open == wrapped_open, "install must be idempotent")

local function flush()
  vim.wait(30, function() return false end, 5)
end
local function current()
  local buf = vim.api.nvim_get_current_buf()
  return buf, assert(view._sessions[buf], "missing result session")
end
local function text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function no_auto_count(start)
  for i = start or 1, #sql_log do
    check(not sql_log[i]:find("COUNT", 1, true), "automatic COUNT reached database: " .. sql_log[i])
  end
end
local function key(buf, lhs)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if map.lhs == lhs then return assert(map.callback, "mapping must have callback")() end
  end
  error("missing mapping " .. lhs)
end

grip.open("people", "mysql://offline/test")
flush()
local buf, session = current()
check(sql_log[1] == 'SELECT * FROM "people" LIMIT 1000', "table query must keep LIMIT 1000")
check(#sql_log == 1, "opening table must execute only data SELECT, not COUNT")
check(#session.state.rows == 1000 and session.total_rows == nil, "1000 loaded rows are not the table total")
check(not text(buf):find("Page 1/", 1, true), "must not display invented page totals")
check(text(buf):find("1000 rows", 1, true) ~= nil, "show actual loaded rows")
local before = #sql_log
key(buf, "]P")
check(#sql_log == before, "jump-to-last with unknown total must not issue a count")
key(buf, "L")
check(#sql_log == before + 1, "next page must issue one data SELECT")
check(session.query_spec.page == 2 and #session.state.rows == 505, "second page must load remaining rows")
check(sql_log[#sql_log]:find("LIMIT 1000 OFFSET 1000", 1, true) ~= nil, "keep page size and offset")
before = #sql_log
key(buf, "L")
check(#sql_log == before and session.query_spec.page == 2, "short last page must not query again")
key(buf, "H")
check(session.query_spec.page == 1 and #session.state.rows == 1000, "previous page still works")

-- 必须清掉过期总数，不能把修改后的筛选钳制在旧页数内。
session.total_rows = 1
session.on_requery(buf, query.set_page(session.query_spec, 2))
check(session.query_spec.page == 2 and session.total_rows == nil, "requery must discard stale total")
row_total = 2
session.on_requery(buf, query.add_filter(session.query_spec, '"id" < 3'))
check(session.query_spec.page == 1 and #session.state.rows == 2, "filter must reset to page 1 without counting")
row_total = 1505
session.on_requery(buf, query.new_table("people", 1000))
check(#session.state.rows == 1000, "clearing filter must not reuse old total or short-page boundary")
session.on_refresh(buf)
check(session.total_rows == nil and #session.state.rows == 1000, "refresh must not acquire totals")

local original_state, original_spec, original_sql = session.state, session.query_spec, session.query_sql
fail_query = true
session.on_requery(buf, query.next_page(session.query_spec))
check(session.state == original_state and session.query_spec == original_spec
  and session.query_sql == original_sql, "failed requery must retain the original page")
fail_query = false
no_auto_count()

-- 表为空、恰好整页、空页返回，均不能循环查询或偷偷补 COUNT。
row_total = 0
grip.open("empty_table", "mysql://offline/test")
flush()
buf, session = current()
before = #sql_log
key(buf, "L")
check(#sql_log == before and #session.state.rows == 0, "empty table cannot page forward")
row_total = 1000
grip.open("exact_page", "mysql://offline/test")
flush()
buf, session = current()
key(buf, "L")
check(session.query_spec.page == 2 and #session.state.rows == 0, "exact multiple permits one empty-page probe")
before = #sql_log
key(buf, "L")
check(#sql_log == before, "empty last page must not continue issuing queries")
key(buf, "H")
check(session.query_spec.page == 1 and #session.state.rows == 1000, "can return from empty last page")
no_auto_count()

-- <leader>sr 保留原始 SQL；原始查询自身就是 COUNT 时也必须执行。
row_total = 1001
local runner = require("config.sql-runner")
before = #sql_log
local saved_view_open = view.open
local ok, err = runner._open_exact_query("SELECT id FROM people;", "mysql://offline/test", {})
check(ok, err)
buf, session = current()
check(view.open == saved_view_open, "exact query must restore the view.open hook")
check(text(buf):find("Page 1/1 (1001 rows)", 1, true) ~= nil,
  "first paint must already use the loaded exact-result count without a second render")
check(not text(buf):find("→L", 1, true), "complete result must not advertise a next page on first paint")
flush()
check(#sql_log == before + 1 and sql_log[#sql_log] == "SELECT id FROM people", "exact query must not wrap LIMIT or count")
check(#session.state.rows == 1001 and session.total_rows == 1001
  and session.query_spec.page_size == 1001, "exact result uses loaded row count")
check(text(buf):find("Page 1/1 (1001 rows)", 1, true) ~= nil, "exact query must render as one complete result")
before = #sql_log
key(buf, "L")
check(#sql_log == before, "complete exact result must not page or count again")
local manual_count = "SELECT COUNT(*) AS _grip_count FROM people"
before = #sql_log
ok, err = runner._open_exact_query(manual_count, "mysql://offline/test", {})
check(ok, err)
check(#sql_log == before + 1 and sql_log[#sql_log] == manual_count, "user-written COUNT must execute unchanged")

-- 作用域外的显式操作仍能生成/执行统计，异常也不能泄漏禁用作用域。
local count_sql = query.build_count_sql(query.new_table("people", 1000))
check(type(count_sql) == "string" and count_sql:find("COUNT", 1, true) ~= nil, "explicit export count must remain available")
local count_result = db.query(count_sql, "mysql://offline/test")
check(tonumber(count_result.rows[1][1]) == 1001, "explicit count reaches database boundary")
local original_blocking = ui.blocking
ui.blocking = function() error("simulated opening exception") end
ok = pcall(grip.open, "people", "mysql://offline/test")
ui.blocking = original_blocking
check(not ok, "opening exception must propagate")
check(type(query.build_count_sql(query.new_table("people", 1000))) == "string", "exception must restore count scope")

print(("PASS: SQL no-count integration (%d checks)"):format(checks))
