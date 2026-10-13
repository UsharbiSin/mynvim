-- nvim --headless -u NONE -i NONE -l tests/sql-metadata-guard.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(vim.fn.stdpath('data') .. '/lazy/dadbod-grip.nvim')
local grip = require('dadbod-grip')
grip.setup({ ai=false, completion=false, discovery=false })
require('config.sql-browser').setup()
require('config.sql-no-count').install()
local guard = require('config.sql-result-guard')
guard.install()
local db = require('dadbod-grip.db')
local normal = db.query
-- 在 adapter 边界返回合成大元数据：既检查 SQL 上限也检查结果解析后的上限。
local adapter = require('dadbod-grip.adapters.mysql')
local previous = adapter.query
adapter.query = function(sql)
  if sql:find('information_schema.TABLES', 1, true) then
    local rows = {}
    for i=1, 59488 do rows[i] = {'t' .. math.floor(i/31), '', 'BASE TABLE', 'c'..i, '', 'int'} end
    return {columns={'table','comment','type','col','colcomment','coltype'},rows=rows,primary_keys={}}
  end
  local rows={}
  for i=1,10001 do rows[i]={tostring(i)} end
  return {columns={'id'},rows=rows,primary_keys={}}
end
local metadata = require('config.sql-metadata')
local tables, err = metadata.fetch('mysql://offline/test')
assert(tables and #tables > 1000, err or 'metadata incorrectly limited')
local value, query_err = db.query('SELECT id FROM people', 'mysql://offline/test')
assert(value == nil and query_err:find('数据行数'), 'normal result budget escaped')
adapter.query=previous
print('PASS: metadata 59488 rows allowed; ordinary 10001 rows blocked')
