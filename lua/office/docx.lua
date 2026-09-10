local process = require('office.process')
local ui = require('office.ui')
local M = {}
local sessions = {}

local function save(buf)
  local session = sessions[buf]
  if not session then return end
  if #session.paragraphs == 0 then
    return vim.notify('Office：文档没有可安全编辑的正文', vim.log.levels.WARN)
  end
  if session.saving then return vim.notify('Office：DOCX 正在保存，请稍候', vim.log.levels.WARN) end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines ~= #session.paragraphs then
    vim.notify('Office：不能新增或删除 DOCX 段落；第一版只支持修改已有段落文字', vim.log.levels.ERROR)
    return
  end
  local changes = {}
  for index, paragraph in ipairs(session.paragraphs) do
    if not paragraph.editable and lines[index] ~= paragraph.text then
      vim.notify(('Office：段落 %d 含复杂结构，拒绝保存'):format(paragraph.paragraph_index + 1), vim.log.levels.ERROR)
      return
    end
    if paragraph.editable and lines[index] ~= paragraph.text then changes[paragraph.id] = lines[index] end
  end
  session.saving = true
  vim.bo[buf].modifiable = false
  process.run('save-docx', session.path, { changes = changes, fingerprint = session.fingerprint }, function(result, err)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    session.saving = false
    vim.bo[buf].modifiable = true
    if not result then return vim.notify('Office：DOCX 保存失败，原文件未改变：' .. err, vim.log.levels.ERROR) end
    for index, paragraph in ipairs(session.paragraphs) do paragraph.text = lines[index] end
    session.fingerprint = result.fingerprint
    vim.bo[buf].modified = false
    if result.saved == 0 then vim.notify('Office：DOCX 没有需要写入的修改')
    else vim.notify(('Office：已安全保存 %d 个段落；首次备份位于 %s'):format(result.saved, result.backup)) end
  end)
end

function M.open(buf, path)
  ui.loading(buf, path)
  process.run('inspect-docx', path, nil, function(result, err)
    if not result then return ui.error(buf, 'DOCX 解析失败：' .. err) end
    if not vim.api.nvim_buf_is_valid(buf) then return end
    ui.prepare(buf, path, 'office-docx')
    local lines = {}
    for _, paragraph in ipairs(result.paragraphs) do lines[#lines + 1] = paragraph.text end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, #lines > 0 and lines or { '（文档没有可安全编辑的正文）' })
    sessions[buf] = { path = path, paragraphs = result.paragraphs, fingerprint = result.fingerprint }
    local namespace = vim.api.nvim_create_namespace('office_docx_readonly')
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for row, paragraph in ipairs(result.paragraphs) do
      local prefix, highlight
      if paragraph.role == 'heading' then
        prefix = string.rep('#', paragraph.level or 1) .. ' '
        highlight = 'Title'
      elseif paragraph.role == 'list' then
        prefix = '• '
      elseif paragraph.role == 'table' then
        prefix = '│ '
      end
      local options = {}
      if prefix then options.virt_text = { { prefix, 'Comment' } }; options.virt_text_pos = 'inline' end
      if highlight then options.line_hl_group = highlight end
      if not paragraph.editable and (paragraph.node_count or 0) > 0 then
        options.line_hl_group = options.line_hl_group or 'Comment'
        options.virt_text = options.virt_text or {}
        options.virt_text[#options.virt_text + 1] = { ' [复杂结构，只读]', 'WarningMsg' }
        options.virt_text_pos = prefix and 'inline' or 'eol'
      end
      if next(options) then
        vim.api.nvim_buf_set_extmark(buf, namespace, row - 1, 0, {
          line_hl_group = options.line_hl_group,
          virt_text = options.virt_text,
          virt_text_pos = options.virt_text_pos,
        })
      end
    end
    vim.api.nvim_create_autocmd('BufWriteCmd', { buffer = buf, callback = function() save(buf) end })
    ui.map(buf, '<leader>op', function() require('office.preview').open(path) end, '高保真预览')
    ui.map(buf, '<leader>oe', function() M.open(buf, path) end, '重新读取可编辑正文')
    ui.map(buf, '<leader>os', function() save(buf) end, '安全保存')
    ui.map(buf, '<leader>or', function() require('office.preview').open(path, true) end, '刷新高保真预览')
    ui.finish(buf)
    if #result.warnings > 0 then vim.notify('Office：' .. table.concat(result.warnings, '\n'), vim.log.levels.WARN) end
  end)
end

return M
