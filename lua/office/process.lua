local platform = require('office.platform')
local M = {}

local function script()
  return vim.fs.joinpath(vim.fn.stdpath('config'), 'scripts', 'office_ooxml.py')
end

function M.run(command, path, input, callback)
  local python = platform.python()
  if not python then
    return callback(nil, 'Office 轻度编辑需要 Python 3，请先安装并加入 PATH')
  end
  local args = { python, script(), command, path }
  local input_path
  if input then
    input_path = vim.fn.tempname() .. '.json'
    local ok, encoded = pcall(vim.json.encode, input)
    if not ok then return callback(nil, '无法编码保存数据：' .. tostring(encoded)) end
    vim.fn.writefile({ encoded }, input_path, 'b')
    vim.list_extend(args, { '--input', input_path })
  end
  vim.system(args, { text = true, timeout = 60000 }, function(result)
    if input_path then vim.uv.fs_unlink(input_path) end
    vim.schedule(function()
      if result.code ~= 0 then
        local stderr, stdout = result.stderr or '', result.stdout or ''
        local message = (stderr ~= '' and stderr or stdout):gsub('%s+$', '')
        callback(nil, message ~= '' and message or ('辅助程序退出码：' .. result.code))
        return
      end
      local ok, decoded = pcall(vim.json.decode, result.stdout)
      if not ok then return callback(nil, '辅助程序返回了无效 JSON：' .. tostring(decoded)) end
      callback(decoded)
    end)
  end)
end

return M
