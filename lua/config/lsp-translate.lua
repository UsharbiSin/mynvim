local M = {}

function M.command(command)
  local proxy = vim.fn.exepath("LspProxy")
  if proxy == "" then
    return command
  end

  local result = { proxy, "--" }
  vim.list_extend(result, command)
  return result
end

return M
