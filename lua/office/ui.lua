local M = {}

function M.prepare(buf, path, filetype)
  vim.bo[buf].buftype = 'acwrite'
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.b[buf].office_source = path
end

function M.loading(buf, path)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '正在读取 Office 文档：' .. path })
  vim.bo[buf].modifiable = false
end

function M.error(buf, message)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'Office 文档读取失败', '', message })
  vim.bo[buf].modifiable = false
  vim.notify('Office：' .. message, vim.log.levels.ERROR)
end

function M.map(buf, lhs, callback, desc)
  vim.keymap.set('n', lhs, callback, { buffer = buf, silent = true, desc = 'Office：' .. desc })
end

function M.finish(buf)
  vim.bo[buf].modified = false
  vim.api.nvim_exec_autocmds('BufReadPost', { buffer = buf, modeline = false })
end

return M
