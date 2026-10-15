-- nvim --headless -u NONE -i NONE -l tests/sql-lint.lua
-- Requires the installed nvim-lint plugin and SQLFluff; no database is used.
local config_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local plugin_root = vim.env.NVIM_LINT_DIR or (vim.fn.stdpath("data") .. "/lazy/nvim-lint")
assert(vim.fn.filereadable(plugin_root .. "/lua/lint/linters/sqlfluff.lua") == 1,
  "nvim-lint not found; set NVIM_LINT_DIR to its checkout")
assert(vim.fn.executable("sqlfluff") == 1, "SQLFluff is required")
vim.opt.runtimepath:prepend(config_root)
vim.opt.runtimepath:append(plugin_root)

local statements = require("config.sql-statements")
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end

for _, sql in ipairs({
  "SHOW PROCESSLIST", "show processlist;", "ShOw FuLl PrOcEsSlIsT;",
  " \tSHOW\nFULL\r\nPROCESSLIST ;\n", "SHOW/**/PROCESSLIST;",
  "/* before */ SHOW /* full */ FULL PROCESSLIST; /* after */",
  "# before\nSHOW PROCESSLIST; # after", "-- before\nSHOW PROCESSLIST -- after\n;",
  "-- before\r\nSHOW PROCESSLIST; -- after\r\n",
  "# before\r\nSHOW PROCESSLIST; # after\r\n",
  "SHOW-- comment\nPROCESSLIST;", "SHOW /* 中文 */ PROCESSLIST;",
}) do
  check(statements.is_processlist(sql), "valid PROCESSLIST rejected: " .. sql)
end

for _, sql in ipairs({
  "", "-- comment only", "SELECT 1;", "SHOW TABLES;", "SHOWPROCESSLIST;",
  "SHOW PROCESSLISTS;", "SHOW FULLPROCESSLIST;", "SHOW PROCESSLIST FULL;",
  "SHOW PROCESSLIST trailing", "SHOW PROCESSLIST;;", ";SHOW PROCESSLIST;",
  "SHOW PROCESSLIST; SELECT 1;", "SHOW PROCESSLIST;\nSELECT FROM;",
  "SHOW PROCESSLIST; SHOW PROCESSLIST;", "SELECT 1; SHOW PROCESSLIST;",
  "SHOW `PROCESSLIST`;", "SHOW 'PROCESSLIST';", "SHOW PROCESSLIST_1;",
  "SHOW PROCESSLIST1;", "SHOW--not_a_comment\nPROCESSLIST;", "SHOW PROCESSLIST--",
  "SHOW /* unfinished PROCESSLIST;", "SHOW /* nested /* comment */ PROCESSLIST;",
  "SHOW /*!50000 FULL */ PROCESSLIST;", "SHOW /*M! FULL */ PROCESSLIST;",
  "SHOW /*m! FULL */ PROCESSLIST;", "SHOW /*+ hint */ PROCESSLIST;",
  "SHOW PROCESSLIST;\0", "SHOW PROCESSLIST; /*! SELECT 1 */",
  "SHOW PROCESSLIST -- comment\r; DELETE FROM orders;",
  "SHOW PROCESSLIST # comment\r; DELETE FROM orders;",
  "SHOW PROCESSLIST -- comment\r; DELETE FROM orders;\n",
  "SHOW PROCESSLIST # comment\r; DELETE FROM orders;\r\n",
}) do
  check(not statements.is_processlist(sql), "unsafe PROCESSLIST accepted: " .. sql)
end
check(not statements.is_processlist(nil), "nil must be rejected")
check(not statements.is_processlist(42), "non-string input must be rejected")

local original_parser = require("lint").linters.sqlfluff.parser
require("config.nvim-lint")
local linter = require("lint").linters.sqlfluff
local command = { linter.cmd }
vim.list_extend(command, linter.args)
local bufnr = vim.api.nvim_create_buf(false, true)

local function lint(sql)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(sql, "\n", { plain = true }))
  local output = vim.fn.system(command, sql)
  check(vim.v.shell_error <= 1, "SQLFluff failed: " .. output)
  return linter.parser(output, bufnr), original_parser(output, bufnr)
end

local function has_code(diagnostics, code)
  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.code == code then return true end
  end
  return false
end

for _, sql in ipairs({
  "SHOW PROCESSLIST;\n", "SHOW PROCESSLIST\n", "show full processlist;\n",
  "/* before */ SHOW /* 中文 */ FULL PROCESSLIST; # after\n",
  "-- before\nSHOW PROCESSLIST;\n",
}) do
  local diagnostics = lint(sql)
  check(not has_code(diagnostics, "PRS"), "known PROCESSLIST PRS was retained: " .. sql)
end

for _, sql in ipairs({
  "SHOW PROCESSLIST trailing;\n", "SHOW PROCESSLIST;\nSELECT FROM;\n",
  "SELECT FROM;\nSHOW PROCESSLIST;\n", "SHOW TABLES;\n",
  "SHOW PROCESSLIST; SHOW PROCESSLIST;\n", "SHOW /*!50000 FULL */ PROCESSLIST;\n",
}) do
  local diagnostics, original = lint(sql)
  check(has_code(original, "PRS"), "fixture must produce a real SQLFluff PRS: " .. sql)
  check(vim.deep_equal(diagnostics, original), "unrelated parsing diagnostics changed: " .. sql)
end

local diagnostics, original = lint("SHOW PROCESSLIST;  \n")
check(has_code(original, "LT01"), "fixture must report trailing whitespace")
check(has_code(diagnostics, "LT01"), "PROCESSLIST must retain layout diagnostics")
check(not has_code(diagnostics, "PRS"), "PROCESSLIST PRS was retained with trailing whitespace")

diagnostics = lint("SELECT\n    *\nFROM orders;\n")
local wildcard
for _, diagnostic in ipairs(diagnostics) do
  if diagnostic.code == "AM04" then wildcard = diagnostic end
end
check(wildcard and wildcard.lnum == 1 and wildcard.col == 4
  and wildcard.end_lnum == 1 and wildcard.end_col == 5,
  "existing AM04 wildcard range adjustment must remain intact")

vim.api.nvim_buf_delete(bufnr, { force = true })
print(("SQL lint: %d checks passed"):format(checks))
