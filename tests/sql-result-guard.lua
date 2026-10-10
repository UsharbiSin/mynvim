-- nvim --headless -u NONE -i NONE -l tests/sql-result-guard.lua
-- 加载真实插件；数据库/凭据/历史均隔离，仅小数据和可控故障。
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(vim.env.DADBOD_GRIP_DIR or (vim.fn.stdpath("data") .. "/lazy/dadbod-grip.nvim"))
vim.o.swapfile = false
local grip = require("dadbod-grip")
local db = require("dadbod-grip.db")
local data = require("dadbod-grip.data")
local query = require("dadbod-grip.query")
local view = require("dadbod-grip.view")
local ui = require("dadbod-grip.ui")
local adapters = require("dadbod-grip.adapters")
local mysql = require("dadbod-grip.adapters.mysql")
local stream = require("config.sql-result-stream")
local importer = require("dadbod-grip.importer")
local editor = require("dadbod-grip.editor")
local editor_save
editor.open = function(_, _, callback) editor_save = callback end
local checks, notifications, queries = 0, {}, {}
local mode, row_total, after_query = "ok", 1001, nil
local copies, renders, imports, received, ordinary = 0, 0, 0, 0, 0
local url = "mysql://offline/test"
local function check(condition, why)
  assert(condition, why)
  checks = checks + 1
end
local function result(count)
  local rows = {}
  for i = 1, count do rows[i] = { tostring(i) } end
  return { columns = { "id" }, rows = rows, primary_keys = { "id" } }
end
local function flush() vim.wait(20, function() return false end, 5) end
vim.notify = function(text) notifications[#notifications + 1] = tostring(text) end
ui.blocking = function(_, callback) return callback() end
ui.confirm = function() return true end
require("dadbod-grip.history").record = function() end
require("dadbod-grip.query_pad").sync_query = function() end
db.is_readonly = function() return false end
db.get_primary_keys = function() return { "id" } end
db.get_column_info = function()
  return { { column_name = "id", data_type = "int", is_nullable = "NO", constraints = "PRIMARY KEY" } }
end
db.execute = function() error("Unexpected database write") end
db.query = function(sql)
  check(type(sql) == "string", "no-count sentinel must be consumed before database")
  queries[#queries + 1] = sql
  if after_query then local fn = after_query; after_query = nil; fn(sql) end
  if mode == "fail" then return nil, "simulated failure" end
  if mode == "wide" then
    return { columns = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }, rows = {} }
  end
  if mode == "bytes" then return { columns = { "id" }, rows = { { string.rep("x", 4097) } } } end
  if sql:find("COUNT", 1, true) then return result(1) end
  return result(math.min(row_total, tonumber(sql:match("LIMIT%s+(%d+)")) or row_total))
end
adapters.run_cmd = function()
  ordinary = ordinary + 1
  return "id\n1\n", "", 0
end
adapters.run_cmd_async = function() error("Unexpected asynchronous database process") end
-- 确认调用约束；真实进程生命周期由 sql-result-stream.lua 套件覆盖。
local receive_failure
stream.run = function(args, _, _, context)
  received = received + 1
  check(context and context.budget.max_rows == 1001, "receiver must get normalized budget")
  if args[1] == "sh" then
    check(context.format == "bytes", "pipe must use byte-only receiving, not MySQL line parsing")
  else
    check(args[1] == "mysql", "only the MySQL result command is captured")
    local before = ordinary
    adapters.run_cmd({ "mysql", "--batch" }, 50, { stdin = "SELECT metadata" })
    check(ordinary == before + 1, "nested metadata must not inherit consumed query context")
  end
  if receive_failure then return "", "[SQL_RESULT_GUARD] simulated receive limit", 125 end
  return "id\n1\n", "", 0
end
local original_new, original_render, original_parse = data.new, view.render, importer.parse
data.new = function(...) copies = copies + 1; return original_new(...) end
view.render = function(...) renders = renders + 1; return original_render(...) end
importer.parse = function(...) imports = imports + 1; return original_parse(...) end

grip.setup({ limit = 1000, ai = false, completion = false, discovery = false, open_sidebar = false })
require("config.sql-browser").setup()
require("config.sql-no-count").install()
local guard = require("config.sql-result-guard")
guard.install({ max_rows = 1001, max_cells = 3300, max_columns = 8, max_bytes = 4096 })
local wrapped = grip.open
guard.install()
check(grip.open == wrapped, "install must be idempotent")
local runner = require("config.sql-runner")
local function current()
  local buf = vim.api.nvim_get_current_buf()
  return buf, assert(view._sessions[buf], "missing result session")
end
local function lines(buf) return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") end
local function open(sql)
  return runner._open_exact_query(sql or "SELECT id FROM people", url, { from_pad = true })
end
local function unchanged(buf, session, before, why)
  check(vim.api.nvim_buf_is_valid(buf), why .. ": old buffer retained")
  check(view._sessions[buf] == session and session.state == before.state, why .. ": old state retained")
  check(vim.deep_equal(session.query_spec, before.spec) and session.query_sql == before.sql,
    why .. ": SQL/filter/sort/page metadata retained")
  check(session.total_rows == before.total and lines(buf) == before.text, why .. ": old display retained")
end
local function saved(buf, session)
  return { state = session.state, spec = vim.deepcopy(session.query_spec), sql = session.query_sql,
    total = session.total_rows, text = lines(buf) }
end

check(open(), "small exact query must succeed")
flush()
local buf, session = current()
check(#session.state.rows == 1001 and session.query_spec.page_size == 1001, "exact query retains all 1001 rows")
check(queries[#queries] == "SELECT id FROM people", "exact query SQL must not acquire LIMIT")
check(lines(buf):find("Page 1/1 (1001 rows)", 1, true), "complete result must display one page")
for _, sql in ipairs(queries) do check(not sql:find("COUNT", 1, true), "must not issue automatic COUNT") end
local before = saved(buf, session)
local previous_copies, previous_renders = copies, renders
row_total = 1002
local ok, err = open()
check(not ok and type(err) == "string", "oversize exact query returns a useful failure")
unchanged(buf, session, before, "row overflow")
check(copies == previous_copies and renders == previous_renders, "reject before copying or rendering")
for _, next_mode in ipairs({ "wide", "bytes", "fail" }) do
  mode = next_mode
  open()
  unchanged(buf, session, before, next_mode .. " failure")
end
mode, row_total = "ok", 5

-- 预检必须早于 view.open 的旧 buffer 删除、render state赋值和apply_edit undo写入。
local oversized = original_new(result(1002))
previous_copies, previous_renders = copies, renders
ok = pcall(data.new, result(1002))
check(not ok and copies == previous_copies, "data.new fallback rejects before deep-copy")
ok = pcall(view.open, oversized, url, "oversize", { reuse_win = vim.api.nvim_get_current_win() })
check(not ok, "view.open refuses an oversized state")
unchanged(buf, session, before, "open preflight")
session._undo_stack, session._redo_stack = { "existing undo" }, { "existing redo" }
ok = pcall(view.apply_edit, buf, oversized)
check(not ok and session._undo_stack[1] == "existing undo" and session._redo_stack[1] == "existing redo",
  "rejected edit must not push undo or clear redo")
ok = pcall(view.render, buf, oversized)
check(not ok and renders == previous_renders, "render fallback stops before renderer")
unchanged(buf, session, before, "render preflight")
session._undo_stack, session._redo_stack = nil, nil

-- 表浏览继续 LIMIT 1000，排序重查；完整查询排序仍仅本地。
row_total = 1001
grip.open("people", url)
flush()
buf, session = current()
check(#session.state.rows == 1000 and queries[#queries]:find("LIMIT 1000", 1, true), "table browser stays bounded at 1000")
local start = #queries
session.on_requery(buf, query.add_sort(session.query_spec, "id", "DESC"))
check(#queries == start + 1 and queries[#queries]:find("ORDER BY", 1, true), "table sorting requeries with ORDER BY")
check(open(), "exact result can be reopened")
flush()
buf, session = current()
start = #queries
require("config.sql-browser").sort_result_column("ASC")
check(#queries == start, "exact-result sorting must not requery")

-- 限额内长字段仍只影响一列40个显示字符，不扩张整张表。
mode = "ok"
row_total = 1
local base_query = db.query
db.query = function() return { columns = { "id" }, rows = { { string.rep("x", 1024) } }, primary_keys = {} } end
check(open("SELECT long_text FROM people"), "long but bounded field is accepted")
db.query = base_query
buf, session = current()
for _, width in pairs(session._render.widths or {}) do check(width <= 40, "column width remains capped at 40") end
check(#lines(buf) < 2500, "one long field must not widen all rendered lines")

-- 状态变换前拒绝大编辑/批量插入；导入在确认和解析前检查原始大小。
grip.open("people", url)
flush()
buf, session = current()
before = saved(buf, session)
ok = pcall(data.insert_rows_with_values, session.state, 1, (function()
  local rows = {}; for i = 1, 1001 do rows[i] = { id = tostring(i) } end; return rows
end)())
check(not ok and next(session.state.inserted) == nil, "bulk insert is rejected before state mutation")
ok = pcall(data.add_change, session.state, 1, "id", string.rep("x", 4097))
check(not ok and next(session.state.changes) == nil, "oversized edited value is refused")
ok = pcall(data.insert_row_with_values, session.state, 1, { id = string.rep("x", 4097) })
check(not ok and next(session.state.inserted) == nil, "single-value insert also uses the guarded bulk boundary")
editor.open("edit id", "1", function(value)
  view.apply_edit(buf, data.add_change(session.state, 1, "id", value))
end)
check(pcall(editor_save, string.rep("x", 4097)), "asynchronous editor rejection must not escape as a Lua error")
unchanged(buf, session, before, "asynchronous edit overflow")
local getreg = vim.fn.getreg
vim.fn.getreg = function() return string.rep("x", 4097) end
local parse_count = imports
grip.do_import("")
check(imports == parse_count, "oversized clipboard must not enter parser")
unchanged(buf, session, before, "clipboard overflow")
vim.fn.getreg = function() return "id\n2\n3\n" end
grip.do_import("")
check(vim.tbl_count(session.state.inserted) == 2, "small import remains staged and editable")
vim.fn.getreg = getreg
receive_failure = true
before = saved(buf, session)
grip.do_import("!printf test")
unchanged(buf, session, before, "pipe overflow")
receive_failure = false

-- mysql.query 的一次性接入不能拦截普通元数据命令，异常也不泄漏作用域。
local count = received
local parsed = mysql.query("SELECT 1 AS id", url)
check(parsed and #parsed.rows == 1 and received == count + 1, "MySQL data query uses guarded receiver")
receive_failure = true
parsed, err = mysql.query("SELECT 1 AS id", url)
check(not parsed and err:find("SQL_RESULT_GUARD", 1, true), "partial/overflow stdout is never parsed")
receive_failure = false
count = received
adapters.run_cmd({ "mysql", "--batch" }, 50, { stdin = "metadata after failure" })
check(received == count, "receiver context must be cleared after failure")

-- A等待时B在同一个session完成；A退出不能恢复A的旧SQL覆盖B。
row_total = 5
grip.open("people", url)
flush()
buf, session = current()
local next_a = query.add_filter(session.query_spec, "id < 4")
local next_b = query.add_filter(session.query_spec, "id < 2")
after_query = function()
  session.on_requery(buf, next_b)
end
session.on_requery(buf, next_a)
check(session.query_sql:find("id < 2", 1, true), "late A cannot overwrite B query SQL")
check(session.query_spec.filters[1].clause == "id < 2", "late A cannot overwrite B filter state")
check(#session.state.rows == 5, "B result remains visible")
local build_before, view_before = query.build_sql, view.open
after_query = function() check(open("SELECT id FROM newer"), "B exact query must complete") end
ok = open("SELECT id FROM older")
check(not ok, "A exact query reports that it was superseded")
buf, session = current()
check(session.query_sql == "SELECT id FROM newer", "new exact result wins")
check(query.build_sql == build_before and view.open == view_before, "nested exact-query wrappers restore correctly")

before = saved(buf, session)
after_query = function() check(guard.cancel(), "manual cancellation sees active query") end
previous_copies = copies
ok = open("SELECT id FROM cancelled")
check(not ok and copies == previous_copies, "cancelled result never enters data.new")
unchanged(buf, session, before, "manual cancel")

-- 本地排序包装在 set_callbacks 之后安装，整条回调链也必须受同一代保护。
row_total = 5
check(open("SELECT id FROM raw_people"), "raw sorting race setup opens")
flush()
buf, session = current()
session.on_requery(buf, query.add_sort(session.query_spec, "id", "ASC"))
next_a = query.add_filter(session.query_spec, "id < 4")
next_b = query.add_filter(session.query_spec, "id < 2")
after_query = function() session.on_requery(buf, next_b) end
session.on_requery(buf, next_a)
check(session.query_sql:find("id < 2", 1, true)
  and session.query_spec.filters[1].clause == "id < 2", "raw sorted A cannot replace B filter metadata")
check(session.query_spec.sorts[1].dir == "ASC", "B local sort remains after superseded A exits")

-- 已完成token不能持有上一份结果，使多次查询串成不会释放的历史链。
local weak = setmetatable({}, { __mode = "k" })
local function previous_result()
  check(open("SELECT id FROM collectible"), "temporary result opens")
  flush()
  local _, old = current()
  weak[old.state] = true
end
previous_result()
check(open("SELECT id FROM final"), "replacement result opens")
flush()
collectgarbage("collect"); collectgarbage("collect")
check(next(weak) == nil, "completed operation must release previous result references")

-- 关闭结果窗时结束本次查询；不在另一个窗口发布迟到结果。
previous_copies = copies
after_query = function() vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true) end
ok = open("SELECT id FROM closing_window")
check(not ok and copies == previous_copies, "window closure rejects the pending result before data copy")

print(("PASS: SQL result guard integration (%d checks)"):format(checks))
