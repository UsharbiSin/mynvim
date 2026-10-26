-- nvim --headless -u NONE -i NONE -l tests/sql-mutation-preview.lua
-- Real visual mapping, runner, Dadbod Grip grid and confirmation callbacks.
-- All database boundaries are replaced: SELECTs run only against a temporary
-- SQLite fixture in query_only mode; mutations are captured and never executed.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local plugin_root = vim.env.DADBOD_GRIP_DIR
  or (vim.fn.stdpath("data") .. "/lazy/dadbod-grip.nvim")
assert(vim.fn.filereadable(plugin_root .. "/lua/dadbod-grip/init.lua") == 1,
  "dadbod-grip.nvim not found; set DADBOD_GRIP_DIR to its checkout")
assert(vim.fn.executable("sqlite3") == 1, "sqlite3 is required")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(plugin_root)
vim.o.swapfile = false
vim.g.mapleader = " "

local cwd, scratch = vim.fn.getcwd(), vim.fn.tempname()
vim.fn.mkdir(scratch, "p")
local database, url = scratch .. "/preview.sqlite3", "mysql://fixture@127.0.0.1/preview"
local null_device = vim.fn.has("win32") == 1 and "NUL" or "/dev/null"
local failures, passed = {}, 0
local queries, executions, notifications, confirmations = {}, {}, {}, {}
local fail_next_query = false
local original_notify, original_confirm = vim.notify, vim.fn.confirm

local function sqlite(sql, csv)
  local command = { "sqlite3", "-init", null_device, "-batch", "-bail" }
  if csv then vim.list_extend(command, { "-header", "-csv" }) end
  command[#command + 1] = database
  local output = vim.fn.system(command, sql)
  assert(vim.v.shell_error == 0, "SQLite fixture rejected preview:\n" .. sql .. "\n" .. output)
  return output
end

local function test(name, run)
  local ok, err = xpcall(run, debug.traceback)
  if ok then passed = passed + 1 else failures[#failures + 1] = name .. "\n" .. err end
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

local function confirm(choice, callback)
  local old = vim.fn.confirm
  vim.fn.confirm = function(prompt, choices, default)
    confirmations[#confirmations + 1] = { prompt = prompt, choices = choices, default = default }
    return choice
  end
  local ok, err = xpcall(callback, debug.traceback)
  vim.fn.confirm = old
  if not ok then error(err, 0) end
end

local suite_ok, suite_err = xpcall(function()
  vim.api.nvim_set_current_dir(scratch)
  sqlite([[
CREATE TABLE people(id INTEGER PRIMARY KEY, dept TEXT, role TEXT, phone TEXT, counter INTEGER);
INSERT INTO people VALUES
  (1, 'old dept', 'old role', 'target', 7),
  (2, 'other dept', 'other role', 'other', 9),
  (3, 'last dept', 'last role', 'last', 11);
]])
  local original_dump = sqlite(".dump")
  local db = require("dadbod-grip.db")
  -- Fail closed if the tested path attempts any additional database operation.
  for _, name in ipairs({
    "ping", "list_tables", "get_referencing_foreign_keys", "get_schema_batch",
    "get_schema_batch_async", "get_indexes", "get_table_stats", "explain",
    "get_constraints", "list_routines", "get_routine_source", "describe_file",
  }) do
    db[name] = function() error("Unexpected database boundary: " .. name, 0) end
  end
  db.query = function(sql, connection)
    assert(connection == url, "unexpected connection")
    assert(sql:match("^%s*[Ss][Ee][Ll][Ee][Cc][Tt]%s"), "preview must be a SELECT")
    queries[#queries + 1] = sql
    if fail_next_query then
      fail_next_query = false
      return nil, "synthetic preview failure"
    end
    -- query_only also rejects accidental writes after a SELECT terminator.
    return db.parse_csv(sqlite("PRAGMA query_only=ON;\n" .. sql, true))
  end
  db.execute = function(sql, connection)
    assert(connection == url, "unexpected mutation connection")
    executions[#executions + 1] = sql
    return ""
  end
  db.get_primary_keys = function(table_name, connection)
    assert(connection == url and (table_name == "people" or table_name == "main.people"))
    return { "id" }
  end
  db.get_column_info = function(table_name, connection)
    assert(connection == url and (table_name == "people" or table_name == "main.people"))
    local columns = {}
    for _, name in ipairs({ "id", "dept", "role", "phone", "counter" }) do
      columns[#columns + 1] = { column_name = name, data_type = "TEXT" }
    end
    return columns
  end
  db.get_foreign_keys = function() return {} end
  db.is_readonly = function(connection)
    assert(connection == url, "unexpected readonly lookup")
    return false
  end
  vim.notify = function(message, level)
    notifications[#notifications + 1] = { message = tostring(message), level = level }
  end
  vim.fn.confirm = function() error("Unexpected confirmation outside an explicit test", 0) end

  local grip = require("dadbod-grip")
  grip.setup({
    completion = false, discovery = false, ai = false, open_sidebar = false,
    connections_path = scratch .. "/connections.json",
  })
  require("dadbod-grip.history").record = function() end
  require("dadbod-grip.query_pad").sync_query = function() end
  -- Keep the upstream implementation for normal calls; use a sentinel solely
  -- to prove other statement types and adapters still reach the original hook.
  local upstream_preview = grip._mutation_preview
  local delegated = {}
  grip._mutation_preview = function(sql, connection, statement, opts)
    if sql == "delegation sentinel" then
      delegated[#delegated + 1] = { connection, statement }
      return "upstream"
    end
    return upstream_preview(sql, connection, statement, opts)
  end

  local preview = require("config.sql-mutation-preview")
  local view = require("dadbod-grip.view")
  local data = require("dadbod-grip.data")
  require("config.sql-runner")
  local visual_mapping
  for _, plugin in ipairs(require("plugins.plugin-list")) do
    if plugin[1] == "joryeugene/dadbod-grip.nvim" then
      for _, mapping in ipairs(plugin.keys) do
        if mapping[1] == "<leader>sr" and mapping.mode == "v" then visual_mapping = mapping end
      end
    end
  end
  assert(visual_mapping, "real visual sr mapping was not found")

  local function plan(sql)
    local parsed, err = preview.parse_update(sql)
    assert(parsed, err)
    assert(parsed.sql:match("^SELECT %* FROM "), "preview must select the affected rows")
    return parsed
  end

  local function selected(sql)
    feed("<Esc>")
    vim.cmd.only({ bang = true, mods = { silent = true } })
    vim.cmd.enew({ bang = true })
    local source = vim.api.nvim_get_current_buf()
    vim.bo[source].bufhidden = "hide"
    vim.bo[source].filetype = "sql"
    local lines = { "SELECT 'previous selection';", "" }
    local statement_lines = vim.split(sql, "\n", { plain = true })
    vim.list_extend(lines, statement_lines)
    vim.list_extend(lines, { "", "SELECT 'outside selection';" })
    vim.api.nvim_buf_set_lines(source, 0, -1, false, lines)
    vim.b[source].sql_connection_url = url
    vim.b[source].sql_connection_name = "isolated fixture"
    vim.keymap.set("v", "<leader>sr", visual_mapping[2], { buffer = source, silent = true })
    queries, executions, notifications, confirmations = {}, {}, {}, {}
    feed("ggV<Esc>")
    local motion = #statement_lines > 1 and ((#statement_lines - 1) .. "j") or ""
    feed("3GV" .. motion .. "<Space>sr")
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), lines),
      "executing sr modified the source SQL")
    local bufnr = vim.api.nvim_get_current_buf()
    local session = assert(view._sessions[bufnr],
      "preview grid missing: " .. vim.inspect(notifications))
    assert(session.pending_mutation and session.pending_mutation.sql == sql,
      "preview did not retain the exact selected UPDATE")
    assert(session.pending_mutation.type == "UPDATE")
    assert(#executions == 0 and #confirmations == 0, "opening a preview must not execute a mutation")
    return session, bufnr
  end

  local update = [[UPDATE people bsp
SET
    bsp.dept = '第四分公司',
    bsp.role = '项目公司设计部负责人'
WHERE
    -- bsp.phone = 'unused'; WHERE and LIMIT inside this comment stay comments
    bsp.phone = 'target']]

  test("visual sr preserves alias and line-comment boundary through the real runner", function()
    local session = selected(update)
    assert(#queries == 1, "preview should query once")
    assert(queries[1]:find("people bsp", 1, true), "table alias was lost")
    assert(queries[1]:find("-- bsp.phone = 'unused'; WHERE and LIMIT inside this comment stay comments\n",
      1, true), "line-comment newline was lost")
    assert(#session.state.rows == 1 and session.state.rows[1][1] == "1",
      "preview included rows outside the selected WHERE")
    assert(session.state.changes[1].dept == "第四分公司"
      and session.state.changes[1].role == "项目公司设计部负责人",
      "qualified SET literals were not staged on the real columns")
    assert(session.state.changes[1]["bsp.dept"] == nil, "alias was mistaken for a column name")
  end)

  test("cancelled confirmation leaves the original statement pending without execution", function()
    local session = selected(update)
    confirm(2, function() feed("a") end)
    assert(#confirmations == 1 and confirmations[1].default == 2)
    assert(#executions == 0 and session.pending_mutation.sql == update)
  end)

  test("confirmed apply executes the original selected UPDATE exactly once", function()
    selected(update)
    confirm(1, function() feed("a") end)
    assert(#confirmations == 1, "apply must request confirmation")
    assert(#executions == 1 and executions[1] == update,
      "apply executed a reconstructed statement or executed more than once")
  end)

  test("U cancels the pending mutation without any execute call", function()
    local _, bufnr = selected(update)
    feed("U")
    local session = view._sessions[bufnr]
    assert(not session or not session.pending_mutation, "cancel retained a pending mutation")
    assert(#executions == 0 and #confirmations == 0)
  end)

  test("refresh repeats the same limited preview and restores literal highlights", function()
    local sql = update .. "\nORDER BY bsp.id DESC LIMIT 1;"
    local session, bufnr = selected(sql)
    local first_query = queries[1]
    confirm(1, function() feed("r") end)
    session = assert(view._sessions[bufnr])
    assert(#queries == 2 and queries[2] == first_query, "refresh changed the preview range")
    assert(session.pending_mutation.sql == sql and session.pending_mutation.row_count == 1)
    assert(session.state.changes[1].dept == "第四分公司", "refresh discarded preview highlights")
    assert(#executions == 0)
  end)

  test("failed refresh retains the last valid rows and pending UPDATE", function()
    local session, bufnr = selected(update)
    local old_state = session.state
    fail_next_query = true
    session.on_refresh(bufnr)
    assert(view._sessions[bufnr].state == old_state, "failed refresh replaced the valid state")
    assert(session.pending_mutation.sql == update and #executions == 0)
    assert(notifications[#notifications].message:find("synthetic preview failure", 1, true))
  end)

  for _, event in ipairs({ "cancel", "replace" }) do
    test("refresh cannot repaint a preview after " .. event .. " during its query", function()
      local session, bufnr = selected(update)
      local old_state, original_query, original_render = session.state, db.query, view.render
      local rendered = false
      local replacement = vim.tbl_extend("force", {}, session, { state = {} })
      db.query = function(sql, connection)
        local result, err = original_query(sql, connection)
        if event == "cancel" then
          session.pending_mutation = nil
        else
          view._sessions[bufnr] = replacement
        end
        return result, err
      end
      view.render = function(...)
        rendered = true
        return original_render(...)
      end
      local ok, err = xpcall(function() session.on_refresh(bufnr) end, debug.traceback)
      db.query, view.render = original_query, original_render
      view._sessions[bufnr] = session
      assert(ok, err)
      assert(not rendered and session.state == old_state,
        "an obsolete preview repainted after its query returned")
      assert(#executions == 0)
    end)
  end

  test("qualified keyword column names cannot start preview clauses", function()
    local suffix = "WHERE p.id = 1 ORDER BY p.id LIMIT 1"
    local parsed = plan("UPDATE people p SET p.where = 'value', p.limit = 5 " .. suffix)
    assert(parsed.sql:find(suffix, 1, true), "qualified SET column became the outer clause")
    assert(not parsed.sql:find("p.where", 1, true) and not parsed.sql:find("p.limit", 1, true),
      "SET assignments leaked into the preview")
  end)

  test("keywords and commas in SET strings do not change WHERE ORDER BY or LIMIT", function()
    local suffix = "WHERE p.id >= 1 ORDER BY p.id DESC LIMIT 1"
    local sql = "UPDATE people p SET p.dept = 'WHERE, ORDER BY LIMIT; -- text', "
      .. "p.role = 'O''Brien' " .. suffix .. ";"
    local parsed = plan(sql)
    assert(parsed.sql:find(suffix, 1, true), "outer query suffix was truncated")
    assert(not parsed.sql:find("WHERE, ORDER", 1, true), "SET text leaked into preview clauses")
    local session = selected(sql)
    assert(#session.state.rows == 1 and session.state.rows[1][1] == "3")
    assert(session.state.changes[1].dept == "WHERE, ORDER BY LIMIT; -- text")
    assert(session.state.changes[1].role == "O'Brien")
  end)

  test("nested SET and WHERE subqueries cannot become outer preview boundaries", function()
    local suffix = [[WHERE p.id IN (
  SELECT id FROM people WHERE counter >= 7 ORDER BY id LIMIT 2
) ORDER BY p.id DESC LIMIT 1]]
    local sql = [[UPDATE people p
SET p.counter = (SELECT max(counter) FROM people WHERE id > 0 ORDER BY id LIMIT 1),
    p.dept = 'new'
]] .. suffix
    local parsed = plan(sql)
    assert(parsed.sql:find(suffix, 1, true), "nested clause was used as the outer WHERE")
    assert(not parsed.sql:find("max(counter)", 1, true))
    local session = selected(sql)
    assert(#session.state.rows == 1 and session.state.rows[1][1] == "2")
    assert(session.state.changes[1].counter == nil, "expression was staged as a literal")
    assert(session.state.changes[1].dept == "new")
  end)

  test("quoted schema table and alias remain valid and metadata uses the base table", function()
    local sql = "UPDATE `main`.`people` AS `p` SET `p`.`dept` = 'quoted' WHERE `p`.`id` = 1;"
    local parsed = plan(sql)
    assert(parsed.table_name == "main.people")
    assert(parsed.sql:find("`main`.`people` AS `p`", 1, true))
    local session = selected(sql)
    assert(session.state.table_name == "main.people" and session.state.changes[1].dept == "quoted")
  end)

  test("source comments and MySQL hash comments retain their newline boundaries", function()
    local sql = [[UPDATE people -- keep alias on the next line
p /* SET fake */ SET p.dept = 'value'
WHERE # WHERE fake ORDER BY id LIMIT 999
p.id = 1 /* LIMIT 999 */ ORDER BY p.id LIMIT 1; -- trailing comment]]
    local parsed = plan(sql)
    assert(parsed.sql:find("-- keep alias on the next line\np", 1, true))
    assert(parsed.sql:find("# WHERE fake ORDER BY id LIMIT 999\np.id", 1, true))
    assert(parsed.sql:find("ORDER BY p.id LIMIT 1", 1, true))
  end)

  test("no-WHERE UPDATE preserves ORDER BY LIMIT and an unrestricted UPDATE previews all rows", function()
    local limited = selected("UPDATE people SET dept = 'limited' ORDER BY id DESC LIMIT 1;")
    assert(#limited.state.rows == 1 and limited.state.rows[1][1] == "3")
    local all = selected("UPDATE people SET dept = 'all';")
    assert(#all.state.rows == 3 and all.pending_mutation.row_count == 3)
    assert(#executions == 0)
  end)

  test("expressions and duplicate assignments are not presented as literal new values", function()
    local session = selected([[UPDATE people
SET counter = counter + 1,
    dept = upper(dept),
    role = 'first', role = 'second'
WHERE id = 1;]])
    assert(next(session.state.changes) == nil, "uncomputed values were staged as literals")
  end)

  test("NULL and signed numbers are staged while empty strings are not mislabeled NULL", function()
    local session = selected("UPDATE people SET dept = NULL, counter = -2, role = '' WHERE id = 1;")
    assert(session.state.changes[1].dept == data.NULL_SENTINEL)
    assert(session.state.changes[1].counter == "-2")
    assert(session.state.changes[1].role == nil, "empty string was mislabeled as NULL")
  end)

  test("empty result still has schema columns and zero pending affected rows", function()
    local session = selected("UPDATE people p SET p.dept = 'none' WHERE p.id = 999;")
    assert(#session.state.rows == 0 and session.pending_mutation.row_count == 0)
    assert(vim.deep_equal(session.state.columns, { "id", "dept", "role", "phone", "counter" }))
    assert(#executions == 0)
  end)

  test("multiple statements and unsupported or ambiguous UPDATE forms fail before querying", function()
    local rejected = {
      "UPDATE people SET dept = 'x'; DELETE FROM people;",
      "UPDATE people SET dept = 'x'; SELECT 1;",
      "UPDATE people SET dept = 'x';;",
      "UPDATE people p JOIN people q ON p.id = q.id SET p.dept = 'x' WHERE p.id = 1",
      "UPDATE people p, people q SET p.dept = 'x' WHERE p.id = q.id",
      "UPDATE (SELECT * FROM people) p SET dept = 'x'",
      "UPDATE people PARTITION (p0) SET dept = 'x'",
      "UPDATE people SET dept = 'unterminated",
      "UPDATE people SET dept = (SELECT dept FROM people",
      "UPDATE people SET dept = 'x' /*! WHERE id = 1 */",
      "UPDATE people /*+ hint */ SET dept = 'x'",
      "UPDATE people SET dept = 'x' /* incomplete",
      "UPDATE `schema.table` SET dept = 'x'",
      "UPDATE people SET dept = 'x' WHERE id = 1 INTO OUTFILE '/tmp/should-not-exist'",
      "UPDATE people SET dept = 'x' WHERE id = 1 UNION SELECT * FROM people",
      "UPDATE people SET dept = 'x' WHERE id = 1 FOR UPDATE",
      "UPDATE people SET dept = 'x' WHERE id = 1 LOCK IN SHARE MODE",
      "UPDATE people SET dept = 'x' WHERE id = 1 PROCEDURE ANALYSE()",
    }
    for _, sql in ipairs(rejected) do
      local parsed, err = preview.parse_update(sql)
      assert(not parsed and type(err) == "string", "unsafe UPDATE accepted: " .. sql)
      local before_queries, before_executions = #queries, #executions
      grip._mutation_preview(sql, url, "UPDATE", {})
      assert(#queries == before_queries and #executions == before_executions,
        "unsupported UPDATE reached the database boundary: " .. sql)
    end
  end)

  test("installation is idempotent and preserves other adapters and mutation types", function()
    local installed = grip._mutation_preview
    preview.install()
    assert(grip._mutation_preview == installed, "install wrapped the hook twice")
    assert(grip._mutation_preview("delegation sentinel", "postgresql://fixture/db", "UPDATE") == "upstream")
    assert(grip._mutation_preview("delegation sentinel", url, "DELETE") == "upstream")
    assert(grip._mutation_preview("delegation sentinel", url, "INSERT") == "upstream")
    assert(#delegated == 3)
  end)

  assert(sqlite(".dump") == original_dump, "a test unexpectedly mutated the SQLite fixture")
end, debug.traceback)

vim.notify, vim.fn.confirm = original_notify, original_confirm
vim.api.nvim_set_current_dir(cwd)
vim.fn.delete(scratch, "rf")
if not suite_ok then failures[#failures + 1] = suite_err end
if #failures > 0 then
  io.stderr:write(table.concat(failures, "\n\n") .. "\n")
  vim.cmd.cquit(1)
end
print(("PASS: SQL mutation preview (%d cases; real sr/grid, isolated SELECTs, captured mutations)"):format(passed))
