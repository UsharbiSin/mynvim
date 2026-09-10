local platform = require('office.platform')
local cache = require('office.cache')
local M = {}
local preview_images = {}

local function notify(message, level)
  vim.schedule(function() vim.notify('Office：' .. message, level or vim.log.levels.INFO) end)
end

local function run(command, callback, timeout)
  vim.system(command, { text = true, timeout = timeout or 120000 }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local stderr, stdout = result.stderr or '', result.stdout or ''
        callback(nil, (stderr ~= '' and stderr or stdout):gsub('%s+$', ''))
      else
        callback(result)
      end
    end)
  end)
end

local function office_to_pdf_windows(source, output, callback)
  local powershell = platform.powershell()
  if not powershell then return callback(nil, '找不到 PowerShell，无法调用 Office COM') end
  local script = vim.fs.joinpath(vim.fn.stdpath('config'), 'scripts', 'office-export.ps1')
  run({ powershell, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script,
    '-InputPath', source, '-OutputPath', output }, callback, 120000)
end

local function office_to_pdf_libreoffice(source, output, callback)
  local executable = platform.libreoffice()
  if not executable then return callback(nil, '找不到 LibreOffice') end
  local output_dir = vim.fs.dirname(output)
  run({ executable, '--headless', '--convert-to', 'pdf', '--outdir', output_dir, source }, function(result, err)
    if not result then return callback(nil, err) end
    local generated = vim.fs.joinpath(output_dir, vim.fn.fnamemodify(source, ':t:r') .. '.pdf')
    if vim.fs.normalize(generated) ~= vim.fs.normalize(output) then
      local ok, rename_err = vim.uv.fs_rename(generated, output)
      if not ok then return callback(nil, tostring(rename_err)) end
    end
    callback(result)
  end)
end

local function office_to_pdf(source, output, callback)
  if platform.is_windows() then
    office_to_pdf_windows(source, output, function(result, err)
      if result then return callback(result) end
      office_to_pdf_libreoffice(source, output, function(fallback, fallback_err)
        if fallback then return callback(fallback) end
        callback(nil, ('Office COM：%s；LibreOffice：%s'):format(err or '不可用', fallback_err or '不可用'))
      end)
    end)
  else
    office_to_pdf_libreoffice(source, output, callback)
  end
end

local function pdf_to_pages(pdf, pages, callback)
  local renderer = platform.pdf_renderer()
  if not renderer then
    return callback(nil, '找不到 PDF 渲染器，请安装 pdftoppm（poppler）或 mutool')
  end
  vim.fn.mkdir(pages, 'p')
  local prefix = vim.fs.joinpath(pages, 'page')
  local command
  if renderer.kind == 'pdftoppm' then
    command = { renderer.command, '-png', '-r', '144', pdf, prefix }
  else
    command = { renderer.command, 'draw', '-r', '144', '-o', prefix .. '-%d.png', pdf }
  end
  run(command, callback, 120000)
end

local function page_files(dir)
  local files = vim.fn.globpath(dir, 'page-*.png', false, true)
  table.sort(files, function(a, b)
    local an = tonumber(a:match('(%d+)%.png$')) or 0
    local bn = tonumber(b:match('(%d+)%.png$')) or 0
    return an < bn
  end)
  return files
end

local function show(path, pages, origin_buf)
  local ok = pcall(function() require('lazy').load({ plugins = { 'image.nvim' } }) end)
  local image_ok, image = pcall(require, 'image')
  local enabled_ok, enabled = false, false
  if image_ok then enabled_ok, enabled = pcall(image.is_enabled) end
  if not ok or not image_ok or not enabled_ok or not enabled then
    notify('图片后端不可用，请在支持图像协议的 WezTerm 中检查 :checkhealth image', vim.log.levels.ERROR)
    return
  end
  vim.cmd('tabnew')
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  vim.api.nvim_buf_set_name(buf, 'office-preview://' .. path)
  local lines = { 'Office 预览：' .. path, '' }
  preview_images[buf] = {}
  for index, page in ipairs(pages) do
    lines[#lines + 1] = ('第 %d 页'):format(index)
    local anchor = #lines
    local height = math.max(12, math.floor(vim.api.nvim_win_get_height(win) * 0.8))
    for _ = 1, height + 1 do lines[#lines + 1] = '' end
    lines[#lines + 1] = ''
    local created, item = pcall(image.from_file, page, {
      buffer = buf, window = win, x = 0, y = anchor,
      height = height,
      with_virtual_padding = false,
    })
    if created and item then preview_images[buf][#preview_images[buf] + 1] = item
    elseif not created then notify(('第 %d 页加载失败：%s'):format(index, item), vim.log.levels.WARN) end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.b[buf].office_source = path
  vim.keymap.set('n', 'q', '<cmd>tabclose<CR>', { buffer = buf, desc = '关闭 Office 预览' })
  vim.schedule(function()
    for _, item in ipairs(preview_images[buf]) do item:render() end
  end)
  if origin_buf and origin_buf ~= buf and vim.api.nvim_buf_is_valid(origin_buf) then
    vim.api.nvim_buf_delete(origin_buf, { force = true })
  end
end

function M.open(path, force)
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  local current = vim.api.nvim_get_current_buf()
  local origin_buf = vim.fs.normalize(vim.api.nvim_buf_get_name(current)) == path
      and vim.bo[current].buftype == '' and current or nil
  if vim.fn.filereadable(path) ~= 1 then return notify('文件不存在：' .. path, vim.log.levels.ERROR) end
  local ok, entry = pcall(cache.entry, path)
  if not ok then return notify(entry, vim.log.levels.ERROR) end
  if force then vim.fn.delete(entry.dir, 'rf') end
  local pages = page_files(entry.pages)
  if #pages > 0 then return show(path, pages, origin_buf) end
  vim.fn.mkdir(entry.dir, 'p')
  notify('正在生成预览，不会阻塞编辑器……')
  local ext = vim.fn.fnamemodify(path, ':e'):lower()
  local function render_pdf(pdf)
    pdf_to_pages(pdf, entry.pages, function(result, err)
      if not result then return notify('PDF 转图片失败：' .. err, vim.log.levels.ERROR) end
      local rendered = page_files(entry.pages)
      if #rendered == 0 then return notify('PDF 渲染完成但没有生成页面', vim.log.levels.ERROR) end
      show(path, rendered, origin_buf)
    end)
  end
  if ext == 'pdf' then
    return render_pdf(path)
  end
  office_to_pdf(path, entry.pdf, function(result, err)
    if not result then
      local help = '。Windows 可安装 Microsoft Office 或 LibreOffice；Linux 请安装 LibreOffice。'
      return notify('文档转 PDF 失败：' .. err .. help, vim.log.levels.ERROR)
    end
    render_pdf(entry.pdf)
  end)
end

function M.close(buf)
  for _, item in ipairs(preview_images[buf] or {}) do pcall(function() item:close() end) end
  preview_images[buf] = nil
end

return M
