-- nvim --headless -u NONE -i NONE -l tests/sql-processlist.lua
-- Real Grip resolver/view/MySQL adapter; only the client process is simulated.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(vim.env.DADBOD_GRIP_DIR
  or (vim.fn.stdpath("data") .. "/lazy/dadbod-grip.nvim"))
vim.o.swapfile = false

local scratch = vim.fn.tempname()
vim.fn.mkdir(scratch, "p")
local url = "mysql://fixture@127.0.0.1:1/fixture"
local original_cwd = vim.fn.getcwd()
vim.api.nvim_set_current_dir(scratch)
local grip = require("dadbod-grip")
grip.setup({ completion = false, discovery = false, ai = false,
  open_sidebar = false, connections_path = scratch .. "/connections.json" })
require("dadbod-grip.history").record = function() end
require("dadbod-grip.query_pad").sync_query = function() end
local browser = require("config.sql-browser")
browser.setup()
require("config.sql-no-count").install()

local runner = require("config.sql-runner")
local view = require("dadbod-grip.view")
local query = require("dadbod-grip.query")
local adapters = require("dadbod-grip.adapters")
local original_run = adapters.run_cmd
local original_notify = vim.notify
local calls, notifications = {}, {}
local expected_sql, fail, empty
local header = "Id\tUser\tHost\tdb\tCommand\tTime\tState\tInfo\n"
adapters.run_cmd = function(args, _, opts)
  assert(args[1] == "mysql", "unexpected adapter")
  assert(opts.stdin == "SET sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES';\n" .. expected_sql,
    "query was rewritten or an extra metadata/COUNT query was issued: " .. tostring(opts.stdin))
  calls[#calls + 1] = opts.stdin
  if fail then return "", "fixture: access denied", 1 end
  return header .. (empty and "" or
    "8\tfixture\tlocalhost\tfixture\tQuery\t0\tinit\tSHOW PROCESSLIST\n"
    .. "3\tfixture\tlocalhost\tfixture\tSleep\t17\t\tNULL\n"), "", 0
end
vim.notify = function(message) notifications[#notifications + 1] = message end

local function current()
  local bid = vim.api.nvim_get_current_buf()
  return assert(view._sessions[bid], "result grid not opened"), bid
end
local function readonly(session)
  assert(session.state.readonly and session.state.table_name == nil and #session.state.pks == 0,
    "process list must never be editable")
  assert(session.on_apply == nil and session.on_delete == nil and session.on_insert == nil,
    "process list must not wire mutation callbacks")
  assert(session.state.sql == expected_sql and session.query_sql == expected_sql,
    "original SQL missing from result")
end
local function open(sql)
  expected_sql = sql
  local before = #calls
  local ok, err = runner._open_exact_query(sql, url, { reuse_win = vim.api.nvim_get_current_win() })
  assert(ok, err)
  assert(#calls == before + 1, "one execution must make one client call")
  vim.wait(20, function() return false end)
  local session, bid = current()
  readonly(session)
  assert(session.query_spec.page == 1 and session.total_rows == #session.state.rows)
  return session, bid
end

local ok, err = xpcall(function()
  -- Ordinary and FULL forms, comments and original casing all reach the client unchanged.
  local session, bid
  for _, sql in ipairs({ "SHOW PROCESSLIST", "SHOW FULL PROCESSLIST;",
      "  show\nprocesslist;  ", "/* inspect */ SHOW PROCESSLIST; -- live sessions" }) do
    session, bid = open(sql)
    assert(#session.state.rows == 2 and session.state.rows[1][1] == "8")
    local before = #calls
    session.on_refresh(bid)
    assert(#calls == before + 1 and session.total_rows == 2)
    readonly(session)
  end

  -- Exercise browser-installed requery wrapper: sort locally, refresh and retain order.
  session, bid = open("SHOW PROCESSLIST;")
  local before = #calls
  session.on_requery(bid, query.toggle_sort(session.query_spec, "Id"))
  assert(#calls == before and session.state._sql_browser_order[1] == 2,
    "sorting must use numeric local order without SQL")
  session.on_refresh(bid)
  assert(#calls == before + 1 and session.state._sql_browser_order[1] == 2,
    "refresh lost local sort")
  readonly(session)

  -- Unsupported wrappers must neither run nor leave fake filter/page state behind.
  local previous_state, previous_spec = session.state, vim.deepcopy(session.query_spec)
  before = #calls
  session.on_requery(bid, query.add_filter(session.query_spec, "Time > 10"))
  session.on_requery(bid, query.next_page(session.query_spec))
  assert(#calls == before and session.state == previous_state)
  assert(vim.deep_equal(session.query_spec, previous_spec), "rejected operation changed the query")

  fail = true
  session.on_refresh(bid)
  assert(session.state == previous_state and session.total_rows == 2,
    "failed refresh discarded previous results")
  assert(notifications[#notifications]:find("access denied", 1, true))
  local opened, open_err = runner._open_exact_query(expected_sql, url)
  assert(not opened and open_err:find("access denied", 1, true), "initial failure was swallowed")
  fail, empty = false, true
  session.on_refresh(bid)
  assert(#session.state.rows == 0 and session.total_rows == 0 and session.query_spec.page_size == 1)
  readonly(session)
  empty = false

  -- Actual normal/visual mapping targets also use the direct command path.
  local source = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(source)
  vim.b[source].sql_connection_url = url
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { "SHOW PROCESSLIST;" })
  expected_sql = "SHOW PROCESSLIST;"
  runner.run_buffer()
  readonly(current())
  vim.api.nvim_set_current_buf(source)
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { "SELECT 1;", "SHOW FULL PROCESSLIST;" })
  vim.api.nvim_buf_set_mark(source, "<", 2, 0, {})
  vim.api.nvim_buf_set_mark(source, ">", 2, 22, {})
  expected_sql = "SHOW FULL PROCESSLIST;"
  runner.run_visual()
  readonly(current())
end, debug.traceback)

for bid in pairs(view._sessions) do pcall(vim.api.nvim_buf_delete, bid, { force = true }) end
vim.wait(20, function() return false end)
adapters.run_cmd, vim.notify = original_run, original_notify
vim.api.nvim_set_current_dir(original_cwd)
vim.fn.delete(scratch, "rf")
if not ok then error(err, 0) end
print("PASS: PROCESSLIST execution/refresh/sort/errors/read-only/normal+visual (real Grip, simulated client)")
