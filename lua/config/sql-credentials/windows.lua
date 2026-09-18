local M = {}

function M.command(name)
  return require("config.sql-credentials").helper_command("get", name)
end

return M
