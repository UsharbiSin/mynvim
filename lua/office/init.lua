local M = {}

local function source_path(buf)
  return vim.b[buf].office_source or vim.api.nvim_buf_get_name(buf)
end

function M.edit(path, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.bo[buf].modified then
    return vim.notify('Office：当前轻度编辑缓冲区尚未保存，请先保存或放弃修改', vim.log.levels.WARN)
  end
  path = vim.fs.normalize(vim.fn.fnamemodify(path or source_path(buf), ':p'))
  require('office.preview').close(buf)
  local ext = vim.fn.fnamemodify(path, ':e'):lower()
  if ext == 'docx' then return require('office.docx').open(buf, path) end
  if ext == 'xlsx' then return require('office.xlsx').open(buf, path) end
  vim.notify('Office：' .. ext .. ' 只支持高保真预览，不支持轻度编辑', vim.log.levels.WARN)
end

function M.setup()
  local group = vim.api.nvim_create_augroup('OfficeDocuments', { clear = true })
  vim.api.nvim_create_autocmd('BufReadCmd', {
    group = group,
    pattern = { '*.docx', '*.xlsx', '*.pptx', '*.pdf', '*.DOCX', '*.XLSX', '*.PPTX', '*.PDF' },
    callback = function(event)
      local path = vim.fs.normalize(vim.fn.fnamemodify(event.file, ':p'))
      local ext = vim.fn.fnamemodify(path, ':e'):lower()
      if ext == 'docx' or ext == 'xlsx' then M.edit(path, event.buf)
      else require('office.preview').open(path) end
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    callback = function(event) require('office.preview').close(event.buf) end,
  })
  vim.api.nvim_create_user_command('OfficePreview', function() require('office.preview').open(source_path(0)) end, {})
  vim.api.nvim_create_user_command('OfficeEdit', function() M.edit(source_path(0)) end, {})
  vim.api.nvim_create_user_command('OfficeSave', function()
    local ft = vim.bo.filetype
    if ft ~= 'office-docx' and ft ~= 'office-xlsx' then
      return vim.notify('Office：当前不是可轻度编辑的 DOCX/XLSX 缓冲区', vim.log.levels.WARN)
    end
    vim.cmd.write()
  end, {})
  vim.api.nvim_create_user_command('OfficeRefresh', function()
    require('office.preview').open(source_path(0), true)
  end, {})
  vim.api.nvim_create_user_command('OfficeHealth', function() vim.cmd.checkhealth('office') end, {})
  vim.keymap.set('n', '<leader>op', '<cmd>OfficePreview<CR>', { desc = 'Office：高保真预览' })
  vim.keymap.set('n', '<leader>oe', '<cmd>OfficeEdit<CR>', { desc = 'Office：轻度编辑' })
end

return M
