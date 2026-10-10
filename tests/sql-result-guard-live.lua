-- 可选真实 MySQL 冒烟：只执行常量 SELECT，不查询业务表、不写入数据。
-- SQL_GUARD_TEST_CONNECTION=连接名 nvim --headless -u NONE -i NONE -l tests/sql-result-guard-live.lua
local name = vim.env.SQL_GUARD_TEST_CONNECTION
assert(name and name ~= "", "必须显式设置 SQL_GUARD_TEST_CONNECTION；默认不连接数据库")
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(vim.env.DADBOD_GRIP_DIR or (vim.fn.stdpath("data") .. "/lazy/dadbod-grip.nvim"))
local credentials = require("config.sql-credentials")
credentials.setup()
local connection
for _, item in ipairs(credentials.connections()) do
  if item.name == name then connection = item; break end
end
assert(connection, "未找到指定的已有连接")
require("config.sql-credentials.grip").install()
require("dadbod-grip").setup({ ai = false, completion = false, discovery = false, timeout = 5000 })
require("config.sql-result-guard").install({
  max_rows = 3, max_cells = 6, max_columns = 2, max_bytes = 256,
})
local stream = require("config.sql-result-stream")
local start, reports = stream.start, {}
stream.start = function(args, timeout, opts, context, callback)
  context.on_finish = function(report) reports[#reports + 1] = report end
  return start(args, timeout, opts, context, callback)
end
local db = require("dadbod-grip.db")
local result, err = db.query("SELECT 1 AS guard_smoke, '中文' AS sample", connection.url)
assert(result and #result.rows == 1 and #result.columns == 2, err or "普通结果未返回")
result, err = db.query("SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4", connection.url)
assert(not result and err and err:find("SQL_RESULT_GUARD", 1, true), "4行结果应在接收阶段拒绝")
assert(reports[#reports].kind == "limit" and reports[#reports].metric == "rows", "未命中流式行数保护")
result, err = db.query("SELECT REPEAT('x', 300) AS payload", connection.url)
assert(not result and err and err:find("SQL_RESULT_GUARD", 1, true), "超大单行应在接收阶段拒绝")
assert(reports[#reports].kind == "limit" and reports[#reports].metric == "bytes", "未命中流式字节保护")
result, err = db.query("SELECT 42 AS recovered", connection.url)
assert(result and result.rows[1][1] == "42", err or "超限后的普通查询未恢复")
print("PASS: real MySQL bounded receive (4 constant SELECTs, no business rows or writes)")
