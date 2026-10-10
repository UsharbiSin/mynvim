-- nvim --headless -u NONE -i NONE -l tests/sql-result-stream.lua
-- 只启动本文件的 Python 客户端替身；不加载连接配置、不访问数据库。
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.o.swapfile = false
local stream = require("config.sql-result-stream")
local checks = 0
local function check(condition, message)
  assert(condition, message)
  checks = checks + 1
end
local function equal(actual, expected, message)
  check(vim.deep_equal(actual, expected), message or "unexpected value")
end
local function collector(limits, format)
  local value, err = stream.new_collector(limits, format)
  return assert(value, err)
end
local function complete(raw, limits, step, format)
  local value = collector(limits, format)
  for index = 1, #raw, step or #raw do
    local ok, err = value:feed(raw:sub(index, index + (step or #raw) - 1))
    assert(ok, err)
  end
  local output, err = value:finish()
  return assert(output, err), value
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local fixture = tmp .. "/mysql"
local marker = tmp .. "/should-not-exist"
vim.fn.writefile(vim.fn.readfile(root .. "/tests/fixtures/sql-result-stream.py", "b"), fixture, "b")
assert(vim.fn.setfperm(fixture, "rwx------") == 1, "cannot make fixture executable")
local python = vim.fn.exepath("python3")
assert(python ~= "", "python3 required for the synthetic client")
local original_system = vim.system
local original_wait = vim.wait
local synthetic_children = {}

local function gone(pid)
  if not pid then return true end
  local ok, alive = pcall(vim.uv.kill, pid, 0)
  return not ok or alive == nil
end

local ok, err = xpcall(function()
  -- Byte-by-byte splitting must preserve UTF-8 and MySQL's escaped field delimiters.
  local raw = "甲\t乙\r\n中\\t文\tline\\nnext\r\n尾\t\\N"
  local output, c = complete(raw, nil, 1)
  equal(output, raw, "chunking altered UTF-8, escapes or CRLF")
  equal(c.stats, { rows = 2, columns = 2, cells = 4, bytes = #raw })
  equal(c:finish(), raw, "finish must be idempotent")
  check(c:feed("late") == false and c.stats.bytes == #raw, "late output must not be retained")
  c:discard()
  check(c.retained_bytes == 0 and c._output == nil, "discard retained complete output")

  c = collector()
  equal(c:finish(), "", "empty output should remain empty")
  equal(c.stats, { rows = 0, columns = 0, cells = 0, bytes = 0 })
  local _, header = complete("name", nil, 1)
  equal(header.stats.rows, 0, "unterminated header is not a data row")
  equal(header.stats.columns, 1)
  local _, empties = complete("name\n\nx\n", nil, 1)
  equal(empties.stats.rows, 2, "empty field record must still count")

  -- Real defaults: allow exactly 10000 rows, reject 10001, and discard all partial data.
  c = collector()
  check(c:feed("h\n" .. string.rep("x\n", 10000)), "10000 rows must be permitted")
  equal(c.stats.rows, 10000)
  check(not c:feed("x\n"), "10001 rows must be rejected")
  equal(c.failure.metric, "rows")
  check(c.retained_bytes == 0 and #c._chunks == 0, "limit kept earlier output")
  check(c:finish() == nil, "partial result returned after row limit")
  local seen = c.stats.bytes
  check(not c:feed(string.rep("x", 1000)) and c.stats.bytes == seen, "late chunks changed failure")

  c = collector({ max_rows = 2 })
  check(c:feed("h\nx\ny\nz"), "unterminated final record should finalize at EOF")
  check(c:finish() == nil and c.failure.metric == "rows", "EOF row escaped the limit")

  -- 10000 x 20 = 200000 cells, independent of the byte budget.
  local row = string.rep("x\t", 19) .. "x\n"
  c = collector()
  check(c:feed(row .. string.rep(row, 10000)), "200000 cells must be permitted")
  equal(c.stats.cells, 200000)
  check(c:finish() ~= nil, "exact cell budget rejected")
  c:discard()
  row = string.rep("x\t", 20) .. "x\n"
  c = collector()
  check(not c:feed(row .. string.rep(row, 9524)), "200004 cells must be rejected before 10000 rows")
  equal(c.failure.metric, "cells")

  local header256 = string.rep("h\t", 255) .. "h\n"
  _, c = complete(header256, nil, 7)
  equal(c.stats.columns, 256, "256 columns must be permitted")
  c = collector()
  check(not c:feed(string.rep("h\t", 256)), "257th column must fail before header completes")
  equal(c.failure.metric, "columns")

  -- Only 16 MiB of synthetic bytes are retained; no grid or large table is constructed.
  c = collector(nil, "bytes")
  local chunk = string.rep("x", 65536)
  for _ = 1, 256 do assert(c:feed(chunk)) end
  equal(c.stats.bytes, 16 * 1024 * 1024)
  local bounded = assert(c:finish())
  equal(#bounded, 16 * 1024 * 1024, "exact byte cap rejected")
  bounded = nil
  c:discard()
  c = collector(nil, "bytes")
  for _ = 1, 256 do assert(c:feed(chunk)) end
  check(not c:feed("x"), "16 MiB + one byte must fail")
  equal(c.failure.metric, "bytes")
  check(c.retained_bytes == 0, "byte limit retained output")
  c = collector({ max_rows = 1, max_cells = 1, max_columns = 1 }, "bytes")
  check(c:feed('"multiline\ncsv",a,b\nx,y,z\n'), "CSV bytes mode interpreted record delimiters")
  equal(c.stats.rows, 0)
  check(c:finish() ~= nil)
  collectgarbage("collect")

  c = collector(nil, "bytes")
  for _ = 1, 262144 do assert(c:feed("x")) end
  check(c:fragment_count() < 512, "one-byte writes accumulated excessive fragment slots")
  equal(#assert(c:finish()), 262144, "fragment compaction lost data")
  c:discard()
  equal(c:fragment_count(), 0, "fragment compaction buffers were not cleared")

  local args = { "mysql", "--defaults-file=/fixture/path", "--batch", "db" }
  local original = vim.deepcopy(args)
  equal(stream.prepare_args(args), { "mysql", "--defaults-file=/fixture/path", "--quick", "--batch", "db" })
  equal(args, original, "argv mutated")
  equal(stream.prepare_args({ "mysql", "--defaults-file", "/fixture/path", "--batch" }),
    { "mysql", "--defaults-file", "/fixture/path", "--quick", "--batch" })
  equal(stream.prepare_args({ "mariadb", "--quick", "--batch" }),
    { "mariadb", "--quick", "--batch" }, "quick duplicated")
  equal(stream.prepare_args({ "mysql", "--batch", "--skip-quick", "--quick=0" }),
    { "mysql", "--quick", "--batch" }, "quick could be disabled after the injected option")
  equal(stream.prepare_args({ "mysql", "--defaults-file", "--quick", "-u", "--skip-quick", "--", "--quick" }),
    { "mysql", "--defaults-file", "--quick", "--quick", "-u", "--skip-quick", "--", "--quick" },
    "quick normalization changed an option value or the database name")
  equal(stream.prepare_args({ "sh", "-s" }, "bytes"), { "sh", "-s" })

  -- Real subprocess: --quick and original stdin/env/clear_env survive the boundary.
  local options = {
    stdin = "SELECT 'literal\\ntext';\n", clear_env = true,
    env = { PATH = vim.env.PATH, SQL_STREAM_TEST_VALUE = "fixture-value" },
  }
  local options_copy = vim.deepcopy(options)
  local stdout, stderr, code, report = stream.run({ fixture, "--batch", "ok" }, 2000, options)
  equal(code, 0, stderr)
  equal(stdout, "quick\tstdin_ok\tenv_ok\n1\t1\t1\n")
  equal(options, options_copy, "process options or env were mutated")
  equal(report.stats.rows, 1)

  stdout, stderr, code = stream.run({ fixture, "unicode" }, 2000, {})
  equal(code, 0, stderr)
  equal(stdout, raw, "real subprocess split bytes incorrectly")

  local context = { budget = { max_rows = 3 }, kill_grace_ms = 30, exit_grace_ms = 300 }
  local active
  context.on_start = function(handle) active = handle end
  stdout, stderr, code, report = stream.run({ fixture, "rows" }, 2000, {}, context)
  equal(code, 125, stderr)
  equal(stdout, "", "row overflow returned a partial result")
  equal(report.metric, "rows")
  check(report.stats.rows > 3 and gone(active.pid), "overflow client still running")
  check(context.cancel == nil and active.is_done(), "completed context was not cleaned")

  stdout, stderr, code, report = stream.run({ fixture, "bytes" }, 2000, {}, {
    format = "bytes", budget = { max_bytes = 4096 }, kill_grace_ms = 30, exit_grace_ms = 300,
  })
  equal(code, 125)
  equal(stdout, "")
  equal(report.metric, "bytes")

  stdout, stderr, code, report = stream.run({ fixture, "stderr" }, 2000, {}, {
    budget = { max_stderr_bytes = 1024 },
  })
  equal(code, 0, stderr)
  equal(stdout, "header\nok\n")
  equal(#stderr, 1024, "stderr exceeded its cap")
  check(report.stderr_truncated and report.stderr_bytes == 32 * 8192)

  stdout, stderr, code, report = stream.run({ fixture, "fail" }, 2000, {})
  equal(code, 7)
  equal(stdout, "", "failed process exposed partial stdout")
  equal(stderr, "fixture failure")

  local finished = 0
  context = { kill_grace_ms = 30, exit_grace_ms = 300,
    on_start = function(handle) active = handle end,
    on_finish = function() finished = finished + 1 end,
  }
  local started = vim.uv.hrtime()
  stdout, stderr, code, report = stream.run({ fixture, "hang" }, 120, {}, context)
  equal(code, 124, stderr)
  equal(stdout, "")
  check((vim.uv.hrtime() - started) / 1e6 < 1200, "timeout did not bound waiting")
  check(gone(active.pid) and report.signal == 9, "SIGTERM-ignoring client was not killed")
  equal(finished, 1)
  check(not active.cancel(), "cancel after completion must be harmless")

  context = { kill_grace_ms = 30, exit_grace_ms = 300,
    on_start = function(handle)
      active = handle
      vim.defer_fn(function() handle.cancel() end, 80)
    end,
  }
  stdout, stderr, code, report = stream.run({ fixture, "hang" }, 2000, {}, context)
  equal(code, 130, stderr)
  equal(stdout, "")
  check(gone(active.pid) and context.cancel == nil, "cancel did not release client/context")

  stdout, stderr, code = stream.run({ fixture, "marker", marker }, 2000, {}, {
    on_start = function(handle) handle.cancel() end,
  })
  equal(code, 130)
  check(vim.fn.filereadable(marker) == 0, "on_start cancellation still spawned the client")

  stdout, stderr, code, report = stream.run({ tmp .. "/missing-secret-fixture-token" }, 500, {
    env = { SQL_STREAM_TEST_VALUE = "private-fixture-token" },
  })
  equal(code, 1)
  equal(report.kind, "spawn")
  check(not stderr:find("fixture%-token") and not stderr:find("secret"), "spawn error leaked argv/env")

  -- A shell import can leave a producer holding stdout after the shell exits.
  -- Only this synthetic child's unique fixture argv may be cleaned up on failure.
  if vim.fn.has("win32") == 0 then
    local pidfile = tmp .. "/producer.json"
    local function quote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
    local shell_input = "trap 'wait; exit 0' TERM\n"
      .. quote(python) .. " " .. quote(fixture) .. " producer " .. quote(pidfile)
      .. " &\nfixture_producer=$!\nwait \"$fixture_producer\"\n"
    local shell_results = {}
    local shell = stream.start({ "sh", "-s" }, 2000, { stdin = shell_input }, {
      format = "bytes", kill_grace_ms = 40, exit_grace_ms = 150,
    }, function(out, _, result_code, meta)
      shell_results[#shell_results + 1] = { out = out, code = result_code, report = meta }
    end)
    check(vim.wait(1000, function() return vim.fn.filereadable(pidfile) == 1 end, 5),
      "synthetic producer did not start")
    local child = vim.json.decode(table.concat(vim.fn.readfile(pidfile), "\n"))
    synthetic_children[#synthetic_children + 1] = child.pid
    equal(child.ppid, shell.pid, "shell unexpectedly replaced itself with the producer")
    check(shell.cancel(), "shell cancellation failed")
    check(vim.wait(1000, function() return #shell_results == 1 end, 5), "shell cancellation did not finish")
    equal(shell_results[1].code, 130)
    equal(shell_results[1].out, "")
    check(gone(shell.pid), "synthetic shell remains alive")
    check(vim.wait(500, function() return gone(child.pid) end, 5),
      "cancel left synthetic producer alive after shell exit; exit_unconfirmed="
        .. tostring(shell_results[1].report.exit_unconfirmed))
    equal(child.pgid, shell.pid, "pipe command did not get its own process group")
    check(not shell_results[1].report.exit_unconfirmed, "producer kept the output pipe open")
    vim.wait(75, function() return false end, 5)
    equal(#shell_results, 1, "producer exit delivered completion twice")
  end

  -- Missing/late exit callbacks cannot keep waiting or deliver a second completion.
  local captured, exit_callback, calls, kills
  calls, kills = 0, {}
  vim.system = function(_, opts, on_exit)
    captured, exit_callback = opts, on_exit
    return { pid = -1, kill = function(_, signal) kills[#kills + 1] = signal end }
  end
  local fake_context = { kill_grace_ms = 5, exit_grace_ms = 10 }
  local fake = stream.start({ "fixture" }, 1000, {}, fake_context, function(out, _, result_code, meta)
    calls = calls + 1
    equal(out, "")
    equal(result_code, 130)
    check(meta.exit_unconfirmed, "missing exit callback wasn't reported")
  end)
  check(fake.cancel(), "first cancellation failed")
  check(not fake.cancel(), "cancellation was not idempotent")
  captured.stdout(nil, string.rep("late", 100))
  check(vim.wait(500, function() return calls == 1 end, 5), "missing exit callback blocked cleanup")
  exit_callback({ code = 0, signal = 0 })
  captured.stdout(nil, "late\n")
  vim.wait(25, function() return false end, 5)
  equal(calls, 1, "late exit callback delivered twice")
  equal(kills, { "sigterm", "sigkill" })
  equal(fake.report.stats.bytes, 0, "output after cancellation accumulated")
  check(fake_context.cancel == nil)
  vim.system = original_system

  -- Two Ctrl-C interruptions may abandon run(), but must not cancel its kill timers
  -- or turn a late successful exit into a published partial result.
  local cleanup_reports, interrupted, late_output, late_exit, interrupted_kills = {}, 0, nil, nil, {}
  vim.system = function(_, opts, on_exit)
    late_output, late_exit = opts.stdout, on_exit
    return { pid = -1, kill = function(_, sig) interrupted_kills[#interrupted_kills + 1] = sig end }
  end
  vim.wait = function(...)
    interrupted = interrupted + 1
    if interrupted <= 2 then return false, -2 end
    return original_wait(...)
  end
  local interrupted_context = { kill_grace_ms = 5, exit_grace_ms = 10,
    on_finish = function(meta) cleanup_reports[#cleanup_reports + 1] = meta end,
  }
  stdout, stderr, code = stream.run({ "fixture" }, 1000, {}, interrupted_context)
  equal(code, 130)
  equal(stdout, "")
  interrupted_context.cancel, interrupted_context.on_finish = nil, nil
  vim.wait = original_wait
  late_output(nil, "late successful-looking result\n")
  check(vim.wait(500, function() return #cleanup_reports == 1 end, 5), "abandoned run lost cleanup")
  late_exit({ code = 0, signal = 0 })
  vim.wait(25, function() return false end, 5)
  equal(interrupted_kills, { "sigterm", "sigkill" }, "context cleanup stopped escalation")
  equal(#cleanup_reports, 1)
  equal(cleanup_reports[1].kind, "cancelled")
  equal(cleanup_reports[1].stats.bytes, 0, "abandoned run accumulated late output")
  vim.system = original_system

  -- Verify timer cleanup after normal completion.
  vim.wait(350, function() return false end, 10)
  check(finished == 1, "timeout or cleanup timer delivered again")
end, debug.traceback)

vim.system = original_system
vim.wait = original_wait
for _, pid in ipairs(synthetic_children) do
  if not gone(pid) then
    local file = io.open("/proc/" .. pid .. "/cmdline", "rb")
    local cmdline = file and file:read(4096) or ""
    if file then file:close() end
    if cmdline:find(fixture, 1, true) and cmdline:find("producer", 1, true) then
      pcall(vim.uv.kill, pid, "sigkill")
    end
  end
end
vim.wait(250, function()
  for _, pid in ipairs(synthetic_children) do if not gone(pid) then return false end end
  return true
end, 5)
vim.fn.delete(tmp, "rf")
if not ok then error(err) end
print(("sql-result-stream: %d checks passed (synthetic clients only)"):format(checks))
