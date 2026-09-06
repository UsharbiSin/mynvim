local M = {}

function M.check()
  vim.health.start("Codex CLI 集成")
  local cmd, err = require("config.codex").command()
  if cmd then
    vim.health.ok("启动命令：" .. vim.inspect(cmd))
  else
    vim.health.warn(err)
  end
  if pcall(require, "snacks.terminal") then
    vim.health.ok("Snacks terminal 可用")
  else
    vim.health.error("Snacks terminal 不可用，请先运行 :Lazy restore")
  end
  vim.health.info("请在系统终端运行 codex --version 和 codex login status 检查 CLI 版本及登录状态。")
end

return M
