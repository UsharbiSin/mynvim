local platform = require('office.platform')
local cache = require('office.cache')
local M = {}
local sessions = {}
local rendering = {}

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
  if not platform.is_windows() then return office_to_pdf_libreoffice(source, output, callback) end
  office_to_pdf_windows(source, output, function(result, err)
    if result then return callback(result) end
    office_to_pdf_libreoffice(source, output, function(fallback, fallback_err)
      if fallback then return callback(fallback) end
      callback(nil, ('Office COM：%s；LibreOffice：%s'):format(err or '不可用', fallback_err or '不可用'))
    end)
  end)
end

local function page_files(dir)
  local files = vim.fn.globpath(dir, 'page-*.png', false, true)
  table.sort(files, function(a, b)
    return (tonumber(a:match('(%d+)%.png$')) or 0) < (tonumber(b:match('(%d+)%.png$')) or 0)
  end)
  return files
end

local function set_status(buf, message)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 1, 2, false, { message })
  vim.bo[buf].modifiable = false
end

local function create_view(path, origin_buf)
  pcall(function() require('lazy').load({ plugins = { 'image.nvim' } }) end)
  local image_ok, image = pcall(require, 'image')
  local enabled_ok, enabled = false, false
  if image_ok then enabled_ok, enabled = pcall(image.is_enabled) end
  if not image_ok or not enabled_ok or not enabled then
    notify('图片后端不可用，请在 WezTerm 中检查 :checkhealth image', vim.log.levels.ERROR)
    return
  end
  vim.cmd('tabnew')
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, ('office-preview://%d/%s'):format(buf, path))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'Office 预览：' .. path, '正在准备文档……' })
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.b[buf].office_source = path
  sessions[buf] = {
    image = image,
    files = {},
    images = {},
    path = path,
    window = vim.api.nvim_get_current_win(),
  }
  vim.keymap.set('n', 'q', '<cmd>tabclose<CR>', { buffer = buf, desc = '关闭 Office 预览' })
  if origin_buf and origin_buf ~= buf and vim.api.nvim_buf_is_valid(origin_buf) then
    vim.api.nvim_buf_delete(origin_buf, { force = true })
  end
  return buf
end

local function append_page(buf, path)
  local session = sessions[buf]
  if not session or session.files[path] or vim.fn.filereadable(path) ~= 1 then return end
  if not vim.api.nvim_win_is_valid(session.window) then return end
  session.files[path] = true
  local page = tonumber(path:match('(%d+)%.png$')) or (#session.images + 1)
  local height = math.max(12, math.floor(vim.api.nvim_win_get_height(session.window) * 0.8))
  local line_count = vim.api.nvim_buf_line_count(buf)
  local block = { ('第 %d 页'):format(page) }
  for _ = 1, height + 2 do block[#block + 1] = '' end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, block)
  vim.bo[buf].modifiable = false
  local created, item = pcall(session.image.from_file, path, {
    buffer = buf,
    window = session.window,
    x = 0,
    y = line_count + 1,
    height = height,
    with_virtual_padding = false,
  })
  if created and item then
    session.images[#session.images + 1] = item
    vim.schedule(function()
      if sessions[buf] then item:render() end
    end)
  elseif not created then
    notify(('第 %d 页加载失败：%s'):format(page, item), vim.log.levels.WARN)
  end
end

local function append_many(buf, files, index)
  index = index or 1
  if not sessions[buf] or index > #files then return end
  append_page(buf, files[index])
  vim.defer_fn(function() append_many(buf, files, index + 1) end, 15)
end

local function render_command(renderer, pdf, prefix, first, last)
  local dpi = tostring(vim.g.office_preview_dpi or 120)
  if renderer.kind == 'pdftoppm' then
    local command = { renderer.command, '-png', '-r', dpi, '-f', tostring(first) }
    if last then vim.list_extend(command, { '-l', tostring(last) }) end
    vim.list_extend(command, { pdf, prefix })
    return command
  end
  local pages = last and (first == last and tostring(first) or ('%d-%d'):format(first, last))
      or ('%d-N'):format(first)
  return { renderer.command, 'draw', '-r', dpi, '-o', prefix .. '-%d.png', pdf, pages }
end

local function page_count(pdf, callback)
  local executable = platform.pdf_info()
  if not executable then return callback() end
  run({ executable, pdf }, function(result)
    local output = result and result.stdout or ''
    callback(tonumber(output:match('Pages:%s+(%d+)')))
  end, 10000)
end

local function poll_pages(buf, dir)
  local timer = vim.uv.new_timer()
  local sizes = {}
  timer:start(200, 200, vim.schedule_wrap(function()
    if not sessions[buf] then timer:stop(); timer:close(); return end
    for _, path in ipairs(page_files(dir)) do
      if not sessions[buf].files[path] then
        local stat = vim.uv.fs_stat(path)
        if stat and stat.size > 0 and sizes[path] == stat.size then append_page(buf, path)
        elseif stat then sizes[path] = stat.size end
      end
    end
  end))
  return timer
end

local function render_pdf(pdf, entry, buf)
  local renderer = platform.pdf_renderer()
  if not renderer then
    return set_status(buf, '缺少 pdftoppm 或 mutool，无法渲染 PDF 页面')
  end
  vim.fn.mkdir(entry.pages, 'p')
  local prefix = vim.fs.joinpath(entry.pages, 'page')
  set_status(buf, '正在生成第一页……')
  page_count(pdf, function(count)
    run(render_command(renderer, pdf, prefix, 1, 1), function(first, first_err)
      if not first then
        rendering[entry.key] = nil
        return set_status(buf, '第一页生成失败：' .. first_err)
      end
      local first_page = page_files(entry.pages)[1]
      if first_page then append_page(buf, first_page) end
      if count == 1 then
        vim.fn.writefile({ '1' }, entry.complete, 'b')
        rendering[entry.key] = nil
        return set_status(buf, '预览完成：共 1 页')
      end
      set_status(buf, count and ('已显示第一页，后台生成其余 %d 页……'):format(count - 1)
        or '已显示第一页，后台生成其余页面……')
      local timer = poll_pages(buf, entry.pages)
      run(render_command(renderer, pdf, prefix, 2, count), function(rest, rest_err)
        timer:stop()
        timer:close()
        rendering[entry.key] = nil
        if not rest then return set_status(buf, '后续页面生成失败：' .. rest_err) end
        local files = page_files(entry.pages)
        for _, path in ipairs(files) do append_page(buf, path) end
        vim.fn.writefile({ tostring(count or #files) }, entry.complete, 'b')
        set_status(buf, ('预览完成：共 %d 页'):format(#files))
      end, 300000)
    end, 120000)
  end)
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
  vim.fn.mkdir(entry.dir, 'p')
  local buf = create_view(path, origin_buf)
  if not buf then return end
  local files = page_files(entry.pages)
  if vim.fn.filereadable(entry.complete) == 1 and #files > 0 then
    set_status(buf, ('使用缓存：共 %d 页'):format(#files))
    return append_many(buf, files)
  end
  if rendering[entry.key] then
    set_status(buf, '该文档正在另一个预览窗口中生成，请稍候后重试')
    return
  end
  rendering[entry.key] = true
  vim.fn.delete(entry.pages, 'rf')
  local ext = vim.fn.fnamemodify(path, ':e'):lower()
  if ext == 'pdf' then return render_pdf(path, entry, buf) end
  if vim.fn.filereadable(entry.pdf) == 1 then return render_pdf(entry.pdf, entry, buf) end
  set_status(buf, '正在由 Office 排版引擎导出 PDF……')
  local temporary = entry.pdf .. '.part.pdf'
  vim.fn.delete(temporary)
  office_to_pdf(path, temporary, function(result, err)
    if not result then
      rendering[entry.key] = nil
      return set_status(buf, '文档转 PDF 失败：' .. err)
    end
    local renamed, rename_err = vim.uv.fs_rename(temporary, entry.pdf)
    if not renamed then
      rendering[entry.key] = nil
      return set_status(buf, '预览缓存写入失败：' .. tostring(rename_err))
    end
    render_pdf(entry.pdf, entry, buf)
  end)
end

function M.close(buf)
  local session = sessions[buf]
  if not session then return end
  for _, item in ipairs(session.images) do pcall(function() item:close() end) end
  sessions[buf] = nil
end

return M
