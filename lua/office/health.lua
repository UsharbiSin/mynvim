local platform = require('office.platform')
local M = {}

function M.check()
  vim.health.start('Office 文档支持')
  local python = platform.python()
  if python then vim.health.ok('Python 3：' .. python)
  else vim.health.error('找不到 Python 3；DOCX/XLSX 轻度编辑不可用') end

  local renderer = platform.pdf_renderer()
  if renderer then vim.health.ok('PDF 渲染器：' .. renderer.command)
  else vim.health.error('找不到 pdftoppm 或 mutool；高保真预览不可用') end

  if platform.is_windows() then
    if platform.powershell() then
      vim.health.ok('PowerShell 可用；将优先尝试 Microsoft Office COM')
      local applications = platform.office_apps()
      for _, name in ipairs({ 'Word.Application', 'Excel.Application', 'PowerPoint.Application' }) do
        if applications[name] then vim.health.ok(name .. ' COM 可用')
        else vim.health.info(name .. ' COM 不可用') end
      end
    else
      vim.health.warn('找不到 PowerShell；不能使用 Microsoft Office COM')
    end
    if platform.libreoffice() then vim.health.ok('LibreOffice fallback 可用')
    else vim.health.info('未找到 LibreOffice；Microsoft Office COM 失败时无法转换') end
  elseif platform.libreoffice() then
    vim.health.ok('LibreOffice：' .. platform.libreoffice())
  else
    vim.health.error('找不到 LibreOffice；Office 文件无法转换为 PDF')
  end

  local image_ok = pcall(require, 'image')
  if image_ok then vim.health.ok('复用现有 image.nvim 图像后端')
  else vim.health.warn('image.nvim 尚未安装或加载；请执行 :Lazy sync') end
end

return M
