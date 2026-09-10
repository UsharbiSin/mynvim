local M = {}

function M.is_windows()
  return vim.fn.has('win32') == 1
end

function M.python()
  for _, name in ipairs(M.is_windows() and { 'python', 'python3' } or { 'python3', 'python' }) do
    local path = vim.fn.exepath(name)
    if path ~= '' then return path end
  end
end

function M.executable(names)
  for _, name in ipairs(names) do
    local path = vim.fn.exepath(name)
    if path ~= '' then return path end
  end
end

function M.pdf_renderer()
  local path = M.executable({ 'pdftoppm' })
  if path then return { kind = 'pdftoppm', command = path } end
  path = M.executable({ 'mutool' })
  if path then return { kind = 'mutool', command = path } end
end

function M.pdf_info()
  return M.executable({ 'pdfinfo' })
end

function M.libreoffice()
  return M.executable({ 'libreoffice', 'soffice' })
end

function M.powershell()
  return M.executable({ 'pwsh', 'powershell' })
end

function M.office_apps()
  if not M.is_windows() or not M.powershell() then return {} end
  local command = table.concat({
    "$names=@('Word.Application','Excel.Application','PowerPoint.Application')",
    '$result=@{}',
    'foreach($name in $names){$result[$name]=([type]::GetTypeFromProgID($name) -ne $null)}',
    '$result|ConvertTo-Json -Compress',
  }, ';')
  local result = vim.system({ M.powershell(), '-NoProfile', '-NonInteractive', '-Command', command }, {
    text = true,
    timeout = 5000,
  }):wait()
  if result.code ~= 0 then return {} end
  local ok, applications = pcall(vim.json.decode, result.stdout)
  return ok and applications or {}
end

return M
