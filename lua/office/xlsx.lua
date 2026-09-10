local process = require('office.process')
local ui = require('office.ui')
local M = {}
local sessions = {}

local function encode(value)
  return value:gsub('\\', '\\\\'):gsub('\t', '\\t'):gsub('\r', '\\r'):gsub('\n', '\\n')
end

local function decode(value)
  local output, index = {}, 1
  while index <= #value do
    local char = value:sub(index, index)
    if char == '\\' and index < #value then
      local next_char = value:sub(index + 1, index + 1)
      output[#output + 1] = ({ t = '\t', r = '\r', n = '\n', ['\\'] = '\\' })[next_char] or next_char
      index = index + 2
    else
      output[#output + 1] = char
      index = index + 1
    end
  end
  return table.concat(output)
end

local function column_name(number)
  local result = ''
  while number > 0 do
    local remainder
    number, remainder = math.floor((number - 1) / 26), (number - 1) % 26
    result = string.char(65 + remainder) .. result
  end
  return result
end

local function column_number(name)
  local result = 0
  for index = 1, #name do result = result * 26 + name:byte(index) - 64 end
  return result
end

local function protected_merged_cells(sheet)
  local protected = {}
  for _, range in ipairs(sheet.merges or {}) do
    local first, last = range:match('^([A-Z]+%d+):([A-Z]+%d+)$')
    if first then
      local first_col, first_row = first:match('^([A-Z]+)(%d+)$')
      local last_col, last_row = last:match('^([A-Z]+)(%d+)$')
      for row = tonumber(first_row), tonumber(last_row) do
        for column = column_number(first_col), column_number(last_col) do
          local reference = column_name(column) .. row
          if reference ~= first then protected[reference] = true end
        end
      end
    end
  end
  return protected
end

local function capture(buf)
  local session = sessions[buf]
  local sheet = session.data.sheets[session.sheet]
  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if all_lines[1] ~= session.title or all_lines[2] ~= session.header then
    return nil, '工作表标题或列标题被修改，拒绝保存'
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 2, -1, false)
  if #lines ~= session.rows then return nil, '不能新增或删除表格行；请只修改单元格内容' end
  local changes = {}
  local merged = protected_merged_cells(sheet)
  for row, line in ipairs(lines) do
    local fields = vim.split(line, '\t', { plain = true })
    if tonumber(fields[1]) ~= row then return nil, ('第 %d 行的行号被修改，拒绝保存'):format(row) end
    for column = 1, session.columns do
      local reference = column_name(column) .. row
      local current = decode(fields[column + 1] or '')
      local original = sheet.cells[reference] or { value = '', kind = 'string' }
      if current ~= original.value then
        if merged[reference] then return nil, reference .. ' 属于合并区域且不是左上角单元格，拒绝修改' end
        local kind = original.kind
        if not sheet.cells[reference] then
          if current:match('^=') then kind = 'new-formula'
          elseif current:upper() == 'TRUE' or current:upper() == 'FALSE' then kind = 'new-boolean'
          elseif tonumber(current) then kind = 'new-number' end
        end
        changes[reference] = { old = original.value, new = current, kind = kind }
      end
    end
  end
  session.pending[tostring(session.sheet - 1)] = changes
  return true
end

local function cell_at_cursor(buf)
  local session = sessions[buf]
  local row, byte_column = unpack(vim.api.nvim_win_get_cursor(0))
  if row < 3 then return end
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, byte_column + 1)
  local column = select(2, before:gsub('\t', ''))
  if column < 1 then return end
  local reference = column_name(column) .. (row - 2)
  local cell = session.data.sheets[session.sheet].cells[reference]
  local lines = { reference, '类型：' .. (cell and cell.kind or '空白') }
  if cell and cell.style then lines[#lines + 1] = '样式索引：' .. cell.style end
  if cell and cell.kind == 'formula' then lines[#lines + 1] = '公式：' .. cell.value end
  vim.notify(table.concat(lines, '\n'))
end

local function render(buf)
  local session = sessions[buf]
  local sheet = session.data.sheets[session.sheet]
  session.rows = math.max(sheet.max_row, 20)
  session.columns = math.max(sheet.max_col, 10)
  local header = { '工作表：' .. sheet.name .. ('（%d/%d）'):format(session.sheet, #session.data.sheets), '' }
  local columns = { '行' }
  for column = 1, session.columns do columns[#columns + 1] = column_name(column) end
  header[2] = table.concat(columns, '\t')
  session.title, session.header = header[1], header[2]
  local pending = session.pending[tostring(session.sheet - 1)] or {}
  local lines = header
  for row = 1, session.rows do
    local values = { tostring(row) }
    for column = 1, session.columns do
      local cell = sheet.cells[column_name(column) .. row]
      local change = pending[column_name(column) .. row]
      values[#values + 1] = encode(change and change.new or (cell and cell.value or ''))
    end
    lines[#lines + 1] = table.concat(values, '\t')
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local has_pending = false
  for _, changes in pairs(session.pending) do
    if next(changes) then has_pending = true break end
  end
  vim.bo[buf].modified = has_pending
end

local function switch(buf, delta)
  local session = sessions[buf]
  if session.saving then return vim.notify('Office：XLSX 正在保存，请稍候', vim.log.levels.WARN) end
  local ok, err = capture(buf)
  if not ok then return vim.notify('Office：' .. err, vim.log.levels.ERROR) end
  session.sheet = ((session.sheet - 1 + delta) % #session.data.sheets) + 1
  render(buf)
end

local function save(buf)
  local session = sessions[buf]
  if session.saving then return vim.notify('Office：XLSX 正在保存，请稍候', vim.log.levels.WARN) end
  local ok, err = capture(buf)
  if not ok then return vim.notify('Office：' .. err, vim.log.levels.ERROR) end
  session.saving = true
  vim.bo[buf].modifiable = false
  process.run('save-xlsx', session.path, {
    changes = session.pending,
    fingerprint = session.data.fingerprint,
  }, function(result, save_err)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if not result then
      session.saving = false
      vim.bo[buf].modifiable = true
      return vim.notify('Office：XLSX 保存失败，原文件未改变：' .. save_err, vim.log.levels.ERROR)
    end
    process.run('inspect-xlsx', session.path, nil, function(data, inspect_err)
      if not vim.api.nvim_buf_is_valid(buf) then return end
      session.saving = false
      vim.bo[buf].modifiable = true
      if not data then return vim.notify('Office：保存成功但刷新失败：' .. inspect_err, vim.log.levels.WARN) end
      session.data, session.pending = data, {}
      render(buf)
      if result.saved == 0 then vim.notify('Office：XLSX 没有需要写入的修改')
      else vim.notify(('Office：已安全保存 %d 个单元格；首次备份位于 %s'):format(result.saved, result.backup)) end
    end)
  end)
end

function M.open(buf, path)
  ui.loading(buf, path)
  process.run('inspect-xlsx', path, nil, function(result, err)
    if not result then return ui.error(buf, 'XLSX 解析失败：' .. err) end
    if not vim.api.nvim_buf_is_valid(buf) then return end
    ui.prepare(buf, path, 'office-xlsx')
    sessions[buf] = { path = path, data = result, sheet = 1, pending = {} }
    render(buf)
    vim.bo[buf].tabstop = 16
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.wo[win].wrap = false
      vim.wo[win].cursorline = true
      vim.wo[win].cursorcolumn = true
    end
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) and vim.fn.exists(':CsvViewEnable') == 2 then
        vim.api.nvim_buf_call(buf, function() vim.cmd('CsvViewEnable') end)
      end
    end)
    vim.api.nvim_create_autocmd('BufWriteCmd', { buffer = buf, callback = function() save(buf) end })
    ui.map(buf, ']s', function() switch(buf, 1) end, '下一个工作表')
    ui.map(buf, '[s', function() switch(buf, -1) end, '上一个工作表')
    ui.map(buf, 'K', function() cell_at_cursor(buf) end, '查看单元格类型、样式或公式')
    ui.map(buf, '<leader>op', function() require('office.preview').open(path) end, '高保真预览')
    ui.map(buf, '<leader>oe', function() M.open(buf, path) end, '重新读取工作簿')
    ui.map(buf, '<leader>os', function() save(buf) end, '安全保存')
    ui.map(buf, '<leader>or', function() require('office.preview').open(path, true) end, '刷新高保真预览')
    ui.finish(buf)
  end)
end

return M
