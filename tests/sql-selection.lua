-- nvim --headless -u NONE -i NONE -l tests/sql-selection.lua
-- 使用实际插件映射和真实按键；仅截获待执行 SQL，不加载数据库或凭据。
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.o.swapfile = false
vim.g.mapleader = " "

local runner = require("config.sql-runner")
local executions, failures = {}, {}
local passed = 0
runner.run = function(sql)
  executions[#executions + 1] = { sql = sql, mode = vim.fn.mode() }
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

local function new_buffer()
  feed("<Esc>")
  vim.cmd.enew({ bang = true })
  vim.bo.bufhidden = "wipe"
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

if #failures > 0 then
  io.stderr:write(table.concat(failures, "\n\n") .. "\n")
  vim.cmd.cquit(1)
end
print(("PASS: SQL selection (%d cases; real mappings and key input, no database)"):format(passed))
