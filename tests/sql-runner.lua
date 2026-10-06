-- Run from the config root:
-- nvim --headless -u NONE -i NONE -l tests/sql-runner.lua
-- DADBOD_GRIP_DIR can point to another installed dadbod-grip.nvim checkout.
-- Exercise the real plugin and SQLite adapter: mocking grip.open hid the
-- conflict with upstream's projection checks.
local config_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local plugin_root = vim.env.DADBOD_GRIP_DIR
  or (vim.fn.stdpath("data") .. "/lazy/dadbod-grip.nvim")
assert(vim.fn.filereadable(plugin_root .. "/lua/dadbod-grip/init.lua") == 1,
  "dadbod-grip.nvim not found; set DADBOD_GRIP_DIR to its checkout")
assert(vim.fn.executable("sqlite3") == 1, "sqlite3 is required")
vim.opt.runtimepath:prepend(config_root)
vim.opt.runtimepath:append(plugin_root)
vim.o.swapfile = false

local original_cwd = vim.fn.getcwd()
local scratch = vim.fn.tempname()
vim.fn.mkdir(scratch, "p")
local database = scratch .. "/runner.sqlite3"
local url = "sqlite:" .. database
local connections_path = scratch .. "/connections.json"
local null_device = vim.fn.has("win32") == 1 and "NUL" or "/dev/null"
local failures, passed = {}, 0

local function sqlite(sql)
  local result = vim.fn.system({ "sqlite3", "-init", null_device, "-bail", database }, sql)
  assert(vim.v.shell_error == 0, result)
  return result
end

local function set_mode(mode)
  vim.fn.writefile({ vim.json.encode({
    { name = "runner regression", url = url, mode = mode },
  }) }, connections_path)
end

-- Every temporary replacement is restored even when an assertion fails.
local function with_override(module, key, replacement, run)
  local original = module[key]
  module[key] = replacement
  local ok, err = xpcall(run, debug.traceback)
  module[key] = original
  if not ok then error(err, 0) end
end

local function test(name, run)
  set_mode("rw")
  local ok, err = xpcall(run, debug.traceback)
  if ok then
    passed = passed + 1
  else
    failures[#failures + 1] = name .. "\n" .. err
  end
end

local suite_ok, suite_err = xpcall(function()
  vim.api.nvim_set_current_dir(scratch)
  sqlite([[
CREATE TABLE orders(id INTEGER PRIMARY KEY, total INTEGER, status TEXT);
INSERT INTO orders VALUES (1, 10, 'open'), (2, 20, 'closed');
CREATE TABLE other_orders(other_id INTEGER PRIMARY KEY, id INTEGER, status TEXT);
INSERT INTO other_orders VALUES (10, 1, 'other');
CREATE TABLE composite(tenant_id INTEGER, id INTEGER, status TEXT,
  PRIMARY KEY(tenant_id, id));
INSERT INTO composite VALUES (1, 1, 'open');
CREATE TABLE base_sms_person(id INTEGER PRIMARY KEY, phone TEXT);
INSERT INTO base_sms_person VALUES (1, 'test-phone'), (2, 'other-phone');
CREATE TABLE base_sms_person_module(id INTEGER PRIMARY KEY, record_id INTEGER, module_name TEXT);
INSERT INTO base_sms_person_module VALUES (11, 1, '异常数据'), (12, 2, '异常数据');
CREATE TABLE many_rows(id INTEGER PRIMARY KEY, status TEXT);
WITH RECURSIVE ids(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM ids WHERE n < 1005)
INSERT INTO many_rows SELECT n, 'open' FROM ids;
]])
  local initial_dump = sqlite(".dump")
  set_mode("rw")
  local grip = require("dadbod-grip")
  grip.setup({
    limit = 1000,
    completion = false,
    discovery = false,
    ai = false,
    open_sidebar = false,
    connections_path = connections_path,
  })
  -- Only disable persistence. Query resolution, database calls, state creation,
  -- rendering and refresh callbacks are the real installed plugin.
  require("dadbod-grip.history").record = function() end
  require("dadbod-grip.query_pad").sync_query = function() end

  local runner = require("config.sql-runner")
  local db = require("dadbod-grip.db")
  local query = require("dadbod-grip.query")
  local view = require("dadbod-grip.view")
  local infer = runner._infer_editable_table

  local function open(sql)
    local original_build, original_page, original_view =
      query.build_sql, query.page_info, view.open
    local ok, err = runner._open_exact_query(sql, url, {
      from_pad = true, reuse_win = vim.api.nvim_get_current_win(),
    })
    assert(ok, err)
    assert(query.build_sql == original_build, "query.build_sql hook leaked")
    assert(query.page_info == original_page, "query.page_info hook leaked")
    assert(view.open == original_view, "view.open hook leaked")
    local bufnr = vim.api.nvim_get_current_buf()
    local session = assert(view._sessions[bufnr], "real result session was not opened")
    assert(session.query_spec.base_sql == sql:gsub(";%s*$", ""),
      "result session does not belong to the executed query")
    assert(#session.state.rows > 0, "fixture query must return a row")
    return session, bufnr
  end

  local function editable(session, table_name, keys)
    assert(session.state.readonly == false, "safe result became read-only")
    assert(session.state.table_name == table_name, "incorrect writeback table")
    assert(vim.deep_equal(session.state.pks, keys or { "id" }), "incorrect primary keys")
  end

  local function readonly(session)
    assert(session.state.readonly == true, "unsafe result was made editable")
    assert(#session.state.pks == 0, "unsafe result retained writeback keys")
  end

  local cte = "WITH x AS (SELECT 1) SELECT id, total, status FROM orders"
  local user_cte = [[WITH role_id AS (
  SELECT id FROM base_sms_person WHERE phone = 'test-phone'
)
SELECT * FROM base_sms_person_module
WHERE record_id IN (SELECT id FROM role_id)
  AND module_name = '异常数据';]]

  test("ordinary SELECT keeps upstream editability", function()
    editable(open("SELECT id, total, status FROM orders"), "orders")
    assert(infer("SELECT id, total FROM orders", "sqlite") == nil,
      "local editability inference must be limited to CTEs")
  end)

  local unsafe_queries = {
    { "ordinary column alias", "SELECT id, total AS status FROM orders" },
    { "ordinary computed column", "SELECT id, total * 2 AS status FROM orders" },
    { "ordinary computed primary key", "SELECT id + 1 AS id, status FROM orders WHERE id = 1" },
    { "CTE column alias", "WITH x AS (SELECT 1) SELECT id, total AS status FROM orders" },
    { "CTE computed primary key", "WITH x AS (SELECT 1) SELECT id + 1 AS id, status FROM orders" },
    { "CTE-derived source", "WITH x AS (SELECT * FROM orders) SELECT * FROM x" },
    { "CTE shadows physical table",
      "WITH orders AS (SELECT id + 1 AS id, status FROM main.orders) SELECT * FROM orders" },
    { "CTE JOIN", "WITH x AS (SELECT 1) SELECT o.* FROM orders o JOIN other_orders a ON a.id = o.id" },
    { "CTE missing primary key", "WITH x AS (SELECT 1) SELECT status FROM orders" },
    { "CTE incomplete composite key", "WITH x AS (SELECT 1) SELECT id, status FROM composite" },
  }
  for _, case in ipairs(unsafe_queries) do
    test(case[1] .. " stays read-only", function() readonly(open(case[2])) end)
  end

  test("simple CTE stays editable after refresh", function()
    local session, bufnr = open(cte)
    editable(session, "orders")
    session.on_refresh(bufnr)
    editable(view._sessions[bufnr], "orders")
  end)
  test("CTE WHERE subquery preserves user's workflow", function()
    local session = open(user_cte)
    editable(session, "base_sms_person_module")
    assert(#session.state.rows == 1 and session.state.rows[1][1] == "11",
      "CTE filter returned an unexpected record")
  end)
  test("CTE requires every composite primary-key column", function()
    editable(open("WITH x AS (SELECT 1) SELECT tenant_id, id, status FROM composite"),
      "composite", { "tenant_id", "id" })
  end)

  test("filter requery preserves safe CTE editability", function()
    local session, bufnr = open(cte)
    session.on_requery(bufnr, query.add_filter(session.query_spec, "id = 2"))
    editable(view._sessions[bufnr], "orders")
    assert(#view._sessions[bufnr].state.rows == 1
      and view._sessions[bufnr].state.rows[1][1] == "2",
      "filter did not run against the database")
  end)

  for _, case in ipairs({
    { "same table projection", "WITH x AS (SELECT 1) SELECT id, total AS status FROM orders" },
    { "different table projection",
      "WITH x AS (SELECT 1) SELECT other_id + 1 AS id, status FROM other_orders" },
    { "different table missing its real primary key",
      "WITH x AS (SELECT 1) SELECT id, status FROM other_orders" },
    { "ordinary unsafe SELECT", "SELECT id + 1 AS id, status FROM orders" },
  }) do
    test("requery rejects stale keys: " .. case[1], function()
      local session, bufnr = open(cte)
      local spec = vim.deepcopy(session.query_spec)
      spec.base_sql = case[2]
      session.on_requery(bufnr, spec)
      readonly(view._sessions[bufnr])
    end)
  end

  test("refresh rejects changed unsafe base SQL", function()
    local session, bufnr = open(cte)
    session.query_spec.base_sql =
      "WITH x AS (SELECT 1) SELECT id + 1 AS id, status FROM orders"
    session.on_refresh(bufnr)
    readonly(view._sessions[bufnr])
  end)

  test("failed requery retains the previous state and query", function()
    local session, bufnr = open(cte)
    local previous_state, previous_spec, previous_sql =
      session.state, session.query_spec, session.query_sql
    local spec = vim.deepcopy(previous_spec)
    spec.base_sql = "WITH x AS (SELECT 1) SELECT * FROM nonexistent_runner_table"
    local notification
    with_override(vim, "notify", function(message) notification = message end, function()
      session.on_requery(bufnr, spec)
    end)
    assert(notification and notification:find("nonexistent_runner_table", 1, true),
      "fixture did not produce the expected database error")
    local current = view._sessions[bufnr]
    assert(current.state == previous_state, "failed query replaced the last valid state")
    assert(current.query_spec == previous_spec and current.query_sql == previous_sql,
      "failed query left the old result attached to a new query")
    editable(current, "orders")
  end)

  test("read-only connection does not gain CTE editability", function()
    set_mode("ro")
    assert(db.is_readonly(url), "fixture read-only profile was not used")
    readonly(open(cte))
  end)
  for _, callback in ipairs({ "on_requery", "on_refresh" }) do
    test("read-only mode survives " .. callback, function()
      local session, bufnr = open(cte)
      set_mode("ro")
      assert(db.is_readonly(url), "fixture read-only profile was not refreshed")
      session[callback](bufnr, session.query_spec)
      readonly(view._sessions[bufnr])
    end)
  end

  test("exact query returns more than 1000 rows without outer LIMIT", function()
    local statement = "SELECT id, status FROM many_rows ORDER BY id"
    local observed, first_page = {}, nil
    local original_query, original_view = db.query, view.open
    with_override(db, "query", function(sql, conn)
      observed[#observed + 1] = sql
      return original_query(sql, conn)
    end, function()
      with_override(view, "open", function(state, conn, sql, opts)
        first_page = query.page_info(opts.query_spec, opts.total_rows)
        return original_view(state, conn, sql, opts)
      end, function()
        local session = open(statement .. ";")
        assert(observed[1] == statement, "exact SQL was wrapped or changed")
        assert(#session.state.rows == 1005, "exact result was truncated")
        assert(first_page == "Page 1/1 (1005 rows)", "first render showed multiple pages")
        assert(session.query_spec.page == 1 and session.query_spec.page_size == 1005,
          "result page size does not match the complete result")
        assert(session.total_rows == 1005, "result row count is incorrect")
      end)
    end)
  end)

  test("temporary hooks are restored after an exception", function()
    local original_build, original_page = query.build_sql, query.page_info
    local failure = function() error("intentional view failure") end
    with_override(view, "open", failure, function()
      local ok, err = runner._open_exact_query(cte, url, { from_pad = true })
      assert(not ok and tostring(err):find("intentional view failure", 1, true),
        "exception was not reported")
      assert(query.build_sql == original_build, "build_sql leaked after exception")
      assert(query.page_info == original_page, "page_info leaked after exception")
      assert(view.open == failure, "view.open leaked after exception")
    end)
    editable(open(cte), "orders")
  end)

  test("MySQL and PostgreSQL pass their projection rules to upstream", function()
    assert(infer("WITH x AS (SELECT 1) SELECT `id`, `status` FROM `orders`", "mysql") == "orders")
    assert(infer("WITH x AS (SELECT 1 ` 2 ` 3) SELECT id FROM orders", "postgresql") == nil,
      "PostgreSQL backtick operators must not be parsed as identifier quotes")
    assert(infer("WITH É AS (SELECT 1) SELECT id FROM é", "mysql") == nil,
      "MySQL Unicode name folding must not bypass CTE shadowing checks")
    assert(infer("WITH x AS (SELECT 1) SELECT id FROM É", "mysql") == nil,
      "unknown MySQL Unicode source normalization must stay read-only")
    assert(infer("WITH x AS (SELECT 1) SELECT id, 姓名 FROM orders", "mysql") == "orders",
      "Unicode base-table columns should still use upstream projection checks")
    assert(infer("WITH x AS (SELECT 1) SELECT id, CURRENT_USER FROM orders", "mysql") == nil,
      "MySQL value expressions must not become editable columns")
    assert(infer("WITH x AS (SELECT 1) SELECT id FROM Orders", "mysql") == "Orders")
    assert(infer("WITH x AS (SELECT 1) SELECT id FROM Orders", "postgresql") == "orders",
      "PostgreSQL identifiers must follow the upstream dialect normalization")
    assert(infer('WITH x AS (SELECT 1) SELECT "id", "status" FROM "orders"', "postgresql") == "orders")
    assert(infer("WITH x AS (SELECT 1) SELECT id, CURRENT_USER FROM orders", "postgresql") == nil,
      "PostgreSQL value expressions must not become editable columns")
  end)

  test("supported CTE headers retain outer-table inference", function()
    for _, statement in ipairs({
      "WITH c AS (SELECT 1), d AS (SELECT 2) SELECT id, status FROM orders",
      "WITH c(value) AS (SELECT 1) SELECT id, status FROM orders",
      "WITH RECURSIVE c(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM c WHERE n < 2)"
        .. " SELECT id, status FROM orders",
      [[WITH "c()"(value) AS (SELECT ')(') SELECT id, status FROM orders]],
    }) do
      assert(infer(statement, "sqlite") == "orders", statement)
    end
  end)

  test("ambiguous or incomplete CTE prefixes stay read-only", function()
    for _, case in ipairs({
      { "postgresql", "WITH c AS (SELECT $$) SELECT id, status FROM orders --$$ AS x)"
        .. " SELECT id, total AS status FROM orders" },
      { "mysql", "WITH /*! orders AS (SELECT id, total AS status FROM real_orders), */"
        .. " helper AS (SELECT 1) SELECT id, status FROM orders" },
      { "sqlite", "WITH c AS (SELECT 1 SELECT id, status FROM orders" },
      { "sqlite", "WITH c AS (SELECT 'unterminated) SELECT id, status FROM orders" },
    }) do
      assert(infer(case[2], case[1]) == nil, case[2])
    end
  end)

  test("case-distinct primary-key names cannot authorize writeback", function()
    -- SQLite supplies a real lowercase id column; simulate PostgreSQL schema
    -- metadata whose quoted primary key is uppercase ID.
    with_override(db, "get_primary_keys", function() return { "ID" } end, function()
      local session = open(cte)
      assert(session.state.columns[1] == "id", "fixture column case changed")
      readonly(session)
    end)
  end)

  test("older upstream resolvers cannot enable CTE editing", function()
    -- grip.open closes over the real resolver; only the exported capability
    -- used by the local extension is replaced with the old permissive behavior.
    with_override(grip, "_resolve_query", function(statement, page_size)
      return query.new_raw(statement, page_size), "orders"
    end, function()
      readonly(open(cte))
    end)
  end)

  test("custom browser filtering preserves safety checks", function()
    require("config.sql-browser").setup()
    local session, bufnr = open(cte)
    session.on_requery(bufnr, query.add_filter(session.query_spec, "id = 2"))
    editable(view._sessions[bufnr], "orders")
    assert(view._sessions[bufnr].state.rows[1][1] == "2")

    session, bufnr = open("WITH x AS (SELECT 1) SELECT id FROM orders")
    local spec = query.add_filter(session.query_spec, "id = -1 UNION ALL SELECT 999")
    session.on_requery(bufnr, spec)
    local current = view._sessions[bufnr]
    assert(#current.state.rows == 1 and current.state.rows[1][1] == "999",
      "fixture did not execute the UNION appended through the filter")
    readonly(current)
  end)

  test("fixture data is unchanged", function()
    assert(sqlite(".dump") == initial_dump, "read/preview tests modified fixture data")
  end)
end, debug.traceback)

-- Close result buffers and drain deferred UI callbacks before removing fixtures.
local loaded_view = package.loaded["dadbod-grip.view"]
if loaded_view then
  for bufnr in pairs(loaded_view._sessions) do
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end
vim.wait(20, function() return false end)
vim.api.nvim_set_current_dir(original_cwd)
vim.fn.delete(scratch, "rf")
assert(vim.fn.isdirectory(scratch) == 0, "temporary database cleanup failed")
if not suite_ok then error(suite_err, 0) end
if #failures > 0 then
  error(("SQL runner: %d passed, %d failed\n%s"):format(
    passed, #failures, table.concat(failures, "\n\n")), 0)
end
print(("PASS: SQL runner (%d cases; real dadbod-grip + temporary SQLite)"):format(passed))
