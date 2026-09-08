-- 官方 Codex CLI 的终端入口；登录、模型和权限沿用 CLI 自身配置。
local M = {}
local sessions = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Codex" })
end

-- 不依赖 autochdir 的瞬时 cwd；.git 目录和 worktree 的 .git 文件均可识别。
function M.root(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.b[buf].codex_root then
    return vim.b[buf].codex_root
  end
  local path = vim.api.nvim_buf_get_name(buf)
  local start = vim.fn.getcwd()
  if vim.bo[buf].buftype == "" and path ~= "" then
    start = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  end
  local root = vim.fs.root(start, ".git") or start
  return vim.fs.normalize(vim.uv.fs_realpath(root) or root)
end

-- 始终使用 argv，避免 shell 拼接和含空格路径的转义问题。
function M.command()
  local cmd = vim.g.codex_cmd
  local windows = vim.fn.has("win32") == 1
  if cmd == nil then
    local exe = windows and vim.fn.exepath("codex.exe") or ""
    if exe == "" then
      exe = vim.fn.exepath("codex")
    end
    if exe == "" then
      return nil, "未找到 Codex CLI。安装并运行 codex login 后重启 Neovim。详见 docs/codex.md。"
    end
    cmd = { exe }
  end
  if type(cmd) ~= "table" or not vim.islist(cmd) or #cmd == 0 then
    return nil, "vim.g.codex_cmd 必须是非空参数数组，例如 { 'codex' }。"
  end
  for _, arg in ipairs(cmd) do
    if type(arg) ~= "string" then
      return nil, "vim.g.codex_cmd 的每个参数必须是字符串。"
    end
  end
  cmd = vim.deepcopy(cmd)
  local exe = vim.fn.exepath(cmd[1])
  if exe == "" then
    return nil, "找不到可执行文件：" .. cmd[1]
  end
  cmd[1] = exe

  -- Windows 的 npm shim 不能作为原生程序直接交给 jobstart。
  -- 通过相邻的官方 JS 入口启动，保留 argv，不改变全局 shell/执行策略。
  if windows and exe:lower():match("%.%a+$") ~= ".exe" then
    local js = vim.fs.joinpath(vim.fs.dirname(exe), "node_modules", "@openai", "codex", "bin", "codex.js")
    local node = vim.fn.exepath("node")
    if node == "" or vim.fn.filereadable(js) ~= 1 then
      return nil, "无法解析 Codex 启动脚本。请安装官方原生 CLI，或用 vim.g.codex_cmd 指定可执行文件及参数。"
    end
    cmd[1] = js
    table.insert(cmd, 1, node)
  end
  return cmd
end

local function running(terminal)
  if not terminal or not terminal:buf_valid() then
    return false
  end
  local job = vim.b[terminal.buf].terminal_job_id
  return job ~= nil and job > 0 and vim.fn.jobwait({ job }, 0)[1] == -1
end

-- Codex 窗口默认用于查看输出和执行 Neovim 操作；需要输入时再手动按 i/a。
local function keep_normal_mode(buf)
  local group = vim.api.nvim_create_augroup("CodexTerminalNormal", { clear = false })
  vim.api.nvim_clear_autocmds({ group = group, buffer = buf })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    buffer = buf,
    callback = function(event)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(event.buf) and vim.api.nvim_get_current_buf() == event.buf then
          vim.cmd("stopinsert")
        end
      end)
    end,
  })
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
      vim.cmd("stopinsert")
    end
  end)
end

local function open(resume)
  local root = M.root()
  local terminal = sessions[root]
  if running(terminal) then
    keep_normal_mode(terminal.buf)
    if resume then
      terminal:show()
      terminal:focus()
      notify("当前项目已有运行中的 Codex；可在 CLI 中用 /resume 选择历史会话。")
    else
      terminal:toggle()
    end
    return terminal
  end

  local cmd, err = M.command()
  if not cmd then
    notify(err, vim.log.levels.WARN)
    return
  end
  if terminal and terminal:buf_valid() then
    terminal:close()
  end
  sessions[root] = nil
  table.insert(cmd, "--no-alt-screen")
  if resume then
    table.insert(cmd, "resume")
  end

  local ok, result = pcall(function()
    return require("snacks").terminal.open(cmd, {
      cwd = root,
      count = 1,
      start_insert = false,
      auto_insert = false,
      auto_close = true,
      win = {
        position = "right",
        width = 0.45,
        wo = { winbar = " Codex " },
        -- Esc 交给 Codex 取消生成；沿用配置中的 Ctrl-t 返回普通模式。
        keys = { term_normal = false },
        on_buf = function(self)
          vim.b[self.buf].codex_root = root
          keep_normal_mode(self.buf)
        end,
      },
    })
  end)
  if not ok then
    notify("启动失败：" .. tostring(result), vim.log.levels.ERROR)
    return
  end
  sessions[root] = result
  return result
end

function M.toggle()
  return open(false)
end

function M.resume()
  return open(true)
end

-- Codex 在磁盘上修改文件；返回编辑器时仅刷新没有未保存编辑的文件。
function M.refresh()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local bo = vim.bo[buf]
      -- autoread 是 global-local 选项，buffer 值为 nil 时继承全局值。
      local autoread = bo.autoread
      if autoread == nil then
        autoread = vim.go.autoread
      end
      if bo.buftype == "" and autoread and not bo.modified and vim.api.nvim_buf_get_name(buf) ~= "" then
        vim.cmd("checktime " .. buf)
      end
    end
  end
end

function M.setup()
  vim.opt.autoread = true
  vim.api.nvim_create_user_command("Codex", M.toggle, { desc = "开关当前项目的 Codex 终端" })
  vim.api.nvim_create_user_command("CodexResume", M.resume, { desc = "恢复当前项目的 Codex 历史会话" })
  local group = vim.api.nvim_create_augroup("CodexRefresh", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermLeave" }, {
    group = group,
    callback = function()
      vim.schedule(M.refresh)
    end,
  })
end

return M
