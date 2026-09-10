-- nvim --headless -u init.lua -l tests/office.lua
local checks = 0

local function check(value, message)
  assert(value, message)
  checks = checks + 1
end

local process = require('office.process')
local original_run = process.run
local saved_docx
local saved_xlsx

process.run = function(command, _, input, callback)
  if command == 'inspect-docx' then
    callback({
      fingerprint = 'docx-before',
      warnings = {},
      paragraphs = {
        { id = 'p0', paragraph_index = 0, text = '项目名称', editable = true },
        { id = 'p1', paragraph_index = 1, text = '复杂域', editable = false },
      },
    })
  elseif command == 'save-docx' then
    saved_docx = input
    callback({ saved = 1, backup = 'sample.docx.office-backup', fingerprint = 'docx-after' })
  elseif command == 'inspect-xlsx' then
    callback({
      fingerprint = 'xlsx-before',
      warnings = {},
      sheets = {
        { name = '施工情况', max_row = 2, max_col = 2, cells = {
          A1 = { value = '项目', kind = 'string' },
          B2 = { value = '=1+1', kind = 'formula' },
        } },
        { name = '统计', max_row = 1, max_col = 1, cells = {} },
      },
    })
  elseif command == 'save-xlsx' then
    saved_xlsx = input
    callback({ saved = 1, backup = 'sample.xlsx.office-backup', fingerprint = 'xlsx-after' })
  else
    error('unexpected command: ' .. command)
  end
end

local docx_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(docx_buf)
require('office.docx').open(docx_buf, 'C:/tmp/sample.docx')
check(vim.bo[docx_buf].filetype == 'office-docx', 'DOCX must use its structured edit filetype')
check(vim.api.nvim_buf_get_lines(docx_buf, 0, -1, false)[1] == '项目名称', 'DOCX text must be editable')
check(vim.fn.maparg('<leader>op', 'n', false, true).buffer == 1, 'DOCX preview mapping must be local')
vim.api.nvim_buf_set_lines(docx_buf, 0, 1, false, { '工程名称' })
vim.fn.maparg('<leader>os', 'n', false, true).callback()
check(saved_docx.fingerprint == 'docx-before', 'DOCX save must carry the source fingerprint')
check(saved_docx.changes.p0 == '工程名称', 'DOCX save must only send changed paragraphs')

local xlsx_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(xlsx_buf)
require('office.xlsx').open(xlsx_buf, 'C:/tmp/sample.xlsx')
check(vim.bo[xlsx_buf].filetype == 'office-xlsx', 'XLSX must use its structured edit filetype')
check(vim.api.nvim_buf_get_lines(xlsx_buf, 0, 1, false)[1]:find('施工情况', 1, true), 'XLSX must show sheet name')
check(vim.fn.maparg(']s', 'n', false, true).buffer == 1, 'XLSX must map next sheet locally')
local row = vim.api.nvim_buf_get_lines(xlsx_buf, 2, 3, false)[1]
local fields = vim.split(row, '\t', { plain = true })
fields[2] = '工程'
vim.api.nvim_buf_set_lines(xlsx_buf, 2, 3, false, { table.concat(fields, '\t') })
vim.fn.maparg('<leader>os', 'n', false, true).callback()
check(saved_xlsx.fingerprint == 'xlsx-before', 'XLSX save must carry the source fingerprint')
check(saved_xlsx.changes['0'].A1.new == '工程', 'XLSX save must identify the exact cell')

check(vim.fn.exists(':OfficePreview') == 2, 'OfficePreview command must exist')
check(vim.fn.exists(':OfficeRefresh') == 2, 'OfficeRefresh command must exist')
check(vim.fn.exists(':OfficeHealth') == 2, 'OfficeHealth command must exist')
check(vim.fn.maparg('<leader>op', 'n', false, true).desc == 'Office：高保真预览', 'global preview mapping must be documented')

process.run = original_run
vim.cmd('silent! %bwipeout!')
io.stdout:write(('PASS: %d Office buffer and command checks\n'):format(checks))
vim.cmd('qa!')
