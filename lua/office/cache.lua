local M = {}

local function hash(value)
  return vim.fn.sha256(value):sub(1, 24)
end

function M.root()
  local root = vim.fs.joinpath(vim.fn.stdpath('cache'), 'office-preview')
  vim.fn.mkdir(root, 'p')
  return root
end

function M.entry(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  local stat = assert(vim.uv.fs_stat(path), '文件不存在：' .. path)
  local key = hash(table.concat({ path, stat.mtime.sec, stat.mtime.nsec, stat.size }, '\0'))
  local dir = vim.fs.joinpath(M.root(), key)
  return {
    key = key,
    dir = dir,
    pdf = vim.fs.joinpath(dir, 'document.pdf'),
    pages = vim.fs.joinpath(dir, 'pages'),
    complete = vim.fs.joinpath(dir, 'complete'),
  }
end

function M.clear(path)
  if path then
    local ok, entry = pcall(M.entry, path)
    if ok then vim.fn.delete(entry.dir, 'rf') end
  else
    vim.fn.delete(M.root(), 'rf')
    vim.fn.mkdir(M.root(), 'p')
  end
end

return M
