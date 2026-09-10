-- nvim --headless -u init.lua -l tests/office-integration.lua
local config = vim.fn.stdpath('config')
local root = vim.fn.tempname() .. ' office 中文'
vim.fn.mkdir(root, 'p')
local python = assert(require('office.platform').python(), 'Python 3 is required')
local fixture = vim.fs.joinpath(config, 'tests', 'office_fixture.py')
local helper = vim.fs.joinpath(config, 'scripts', 'office_ooxml.py')
local checks = 0

local function check(value, message)
  assert(value, message)
  checks = checks + 1
end

local function create(path)
  local result = vim.system({ python, fixture, path }, { text = true }):wait()
  assert(result.code == 0, result.stderr)
end

local function wait_for(predicate, message)
  check(vim.wait(10000, predicate, 20), message)
end

local function test()
  local docx = vim.fs.joinpath(root, '中文 文档.docx')
  create(docx)
  vim.cmd.edit(vim.fn.fnameescape(docx))
  wait_for(function() return vim.bo.filetype == 'office-docx' end, 'DOCX edit buffer did not load')
  check(vim.api.nvim_get_current_line() == 'Office 预览测试', 'DOCX text extraction failed')
  vim.api.nvim_set_current_line('Office 保存测试')
  vim.cmd.write()
  wait_for(function() return not vim.bo.modified end, 'DOCX asynchronous save did not finish')
  check(vim.fn.filereadable(docx .. '.office-backup') == 1, 'DOCX first-save backup is missing')
  local docx_check = vim.system({ python, helper, 'validate', docx }, { text = true }):wait()
  check(docx_check.code == 0, 'saved DOCX validation failed: ' .. docx_check.stderr)

  local xlsx = vim.fs.joinpath(root, '中文 表格.xlsx')
  create(xlsx)
  vim.cmd.edit(vim.fn.fnameescape(xlsx))
  wait_for(function() return vim.bo.filetype == 'office-xlsx' end, 'XLSX edit buffer did not load')
  local fields = vim.split(vim.api.nvim_buf_get_lines(0, 2, 3, false)[1], '\t', { plain = true })
  check(fields[2] == 'old', 'XLSX cell extraction failed')
  fields[2] = 'new'
  vim.api.nvim_buf_set_lines(0, 2, 3, false, { table.concat(fields, '\t') })
  vim.cmd.write()
  wait_for(function() return not vim.bo.modified end, 'XLSX asynchronous save did not finish')
  check(vim.fn.filereadable(xlsx .. '.office-backup') == 1, 'XLSX first-save backup is missing')
  local xlsx_check = vim.system({ python, helper, 'validate', xlsx }, { text = true }):wait()
  check(xlsx_check.code == 0, 'saved XLSX validation failed: ' .. xlsx_check.stderr)
end

local ok, err = xpcall(test, debug.traceback)
vim.cmd('silent! %bwipeout!')
vim.fn.delete(root, 'rf')
if not ok then
  io.stderr:write('FAIL: ' .. err .. '\n')
  vim.cmd('cquit 1')
else
  io.stdout:write(('PASS: %d end-to-end Office checks\n'):format(checks))
  vim.cmd('qa!')
end
