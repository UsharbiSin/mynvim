local M = {}

function M.command(name)
  local tool = vim.fn.exepath("secret-tool")
  if tool == "" then
    return nil, "未找到 secret-tool；Arch 请安装 libsecret 和一个 Secret Service 钥匙环服务"
  end
  return { tool, "lookup", "application", "nvim-sql", "connection", name }
end

return M
