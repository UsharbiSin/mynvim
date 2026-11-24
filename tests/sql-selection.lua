-- nvim --headless -u NONE -i NONE -l tests/sql-selection.lua
-- 使用实际插件映射和真实按键；仅截获待执行 SQL，不加载数据库或凭据。
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.o.swapfile = false
vim.g.mapleader = " "

local runner = require("config.sql-runner")
local executions, failures = {}, {}
local passed = 0
local connection = { name = "test", url = "sqlite:test" }
local pending_choice
runner.connections = function() return { connection } end
vim.ui.select = function(items, _, on_choice)
  assert(items[1] == connection and not pending_choice, "unexpected database picker")
  pending_choice = on_choice
end
package.loaded["config.sql-result-guard"] = {
  exact_query = function(_, sql, url, opts)
    executions[#executions + 1] = {
      sql = sql, mode = vim.fn.mode(), url = url, path = opts.source_path,
      buf = vim.api.nvim_get_current_buf(), win = vim.api.nvim_get_current_win(),
    }
    return true
  end,
}

local function choose(item)
  local callback = assert(pending_choice, "database picker did not open")
  pending_choice = nil
  callback(item)
end

local mappings = {}
for _, plugin in ipairs(require("plugins.plugin-list")) do
  if plugin[1] == "joryeugene/dadbod-grip.nvim" then
    for _, key in ipairs(plugin.keys) do
      if key[1] == "<leader>sr" then
        mappings[#mappings + 1] = key
      end
    end
  end
end
assert(#mappings == 2, "expected normal and visual SQL execution mappings")

local lines = {
  "SELECT id FROM oversized_table;",
  "-- 上一次选区；不能再次执行。",
  "",
  "SELECT",
  "    id,",
  "    -- 保留注释中的分号;",
  "    name",
  "FROM people",
  "WHERE id <= 336;",
  "",
  "SELECT 'last' AS marker;",
}
local selected_sql = table.concat(vim.list_slice(lines, 4, 9), "\n")

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

local function new_buffer(needs_connection)
  feed("<Esc>")
  vim.cmd.enew({ bang = true })
  vim.bo.bufhidden = "wipe"
  pending_choice = nil
  if not needs_connection then vim.b.sql_connection_url = connection.url end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  for _, key in ipairs(mappings) do
    vim.keymap.set(key.mode or "n", key[1], key[2], { buffer = true, silent = true })
  end
  executions = {}
end

local function expect_execution(expected)
  assert(#executions == 1, "expected exactly one execution, got " .. #executions)
  assert(executions[1].sql == expected,
    ("wrong SQL range: expected %q, got %q"):format(expected, executions[1].sql))
  assert(executions[1].mode == "n", "SQL execution must leave Visual/Select mode")
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), lines),
    "executing the mapping changed the SQL buffer")
end

local function test(name, callback)
  local ok, err = xpcall(callback, debug.traceback)
  if ok then
    passed = passed + 1
  else
    failures[#failures + 1] = name .. "\n" .. err
  end
end

test("first selection has no historical marks", function()
  new_buffer()
  assert(vim.fn.line("'<") == 0 and vim.fn.line("'>") == 0)
  feed("4GV5j<Space>sr")
  expect_execution(selected_sql)
end)

for _, case in ipairs({
  { "forward line selection", "4GV5j" },
  { "reverse line selection", "9GV5k" },
  { "character selection uses complete lines", "4G0v5j" },
  { "reverse character selection", "9G0v5k" },
  { "block selection uses complete lines", "4G0<C-V>5j" },
  { "line Select mode", "4GV5j<C-G>" },
  { "character Select mode", "4G0v5j<C-G>" },
  { "block Select mode", "4G0<C-V>5j<C-G>" },
}) do
  test(case[1] .. " ignores stale marks", function()
    new_buffer()
    feed("ggVj<Esc>")
    assert(vim.fn.line("'<") == 1 and vim.fn.line("'>") == 2)
    feed(case[2] .. "<Space>sr")
    expect_execution(selected_sql)
  end)
end

test("successive executions use the new selection", function()
  new_buffer()
  feed("4GV5j<Space>sr")
  expect_execution(selected_sql)
  executions = {}
  feed("11GV<Space>sr")
  expect_execution(lines[11])
end)

test("normal mode still executes the whole buffer", function()
  new_buffer()
  feed("ggVj<Esc><Space>sr")
  expect_execution(table.concat(lines, "\n"))
end)

test("choosing a database resumes the original selection in its source window", function()
  new_buffer(true)
  local source, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  local path = vim.fn.tempname() .. ".sql"
  vim.api.nvim_buf_set_name(source, path)
  feed("4GV5j<Space>sr")
  assert(#executions == 0)
  vim.api.nvim_buf_set_lines(source, 3, 4, false, { "-- edited after opening picker" })
  vim.cmd.new()
  local other = vim.api.nvim_get_current_buf()
  choose(connection)
  assert(#executions == 1)
  local result = executions[1]
  assert(result.sql == selected_sql and result.url == connection.url)
  assert(result.buf == source and result.win == win and result.path == path)
  assert(runner.current_connection(source).name == connection.name)
  assert(not runner.current_connection(other))

  vim.api.nvim_set_current_win(win)
  feed("11GV<Space>sr")
  assert(#executions == 2 and executions[2].sql == lines[11] and not pending_choice)
end)

test("cancelling leaves the buffer disconnected and allows a fresh run", function()
  new_buffer(true)
  feed("<Space>sr")
  choose(nil)
  assert(not runner.current_connection() and #executions == 0)
  feed("<Space>sr")
  choose(connection)
  expect_execution(table.concat(lines, "\n"))
end)

test("closing the source window while choosing abandons the query", function()
  new_buffer(true)
  feed("<Space>sr")
  local win = vim.api.nvim_get_current_win()
  vim.cmd.new()
  vim.api.nvim_win_close(win, true)
  choose(connection)
  assert(#executions == 0 and not runner.current_connection())
end)

test("empty SQL skips the database picker", function()
  new_buffer(true)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "  " })
  feed("<Space>sr")
  assert(#executions == 0 and not pending_choice)
end)

if #failures > 0 then
  io.stderr:write(table.concat(failures, "\n\n") .. "\n")
  vim.cmd.cquit(1)
end
print(("PASS: SQL selection (%d cases; real mappings and key input, no database)"):format(passed))
