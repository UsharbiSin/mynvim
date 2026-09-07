local M = {}

local is_win = vim.fn.has("win32") == 1

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "一键运行" })
end

local function executable(name)
  local path = vim.fn.exepath(name)
  if path == "" then
    notify("找不到可执行文件：" .. name, vim.log.levels.ERROR)
    return nil
  end
  return path
end

local function terminal(command, cwd)
  command = vim.deepcopy(command)
  command[1] = executable(command[1])
  if not command[1] then
    return false
  end

  if #vim.api.nvim_list_uis() == 0 then
    local result = vim.system(command, { cwd = cwd, text = true }):wait()
    if result.stdout and result.stdout ~= "" then
      print(vim.trim(result.stdout))
    end
    if result.code ~= 0 then
      local output = result.stderr ~= "" and result.stderr or result.stdout
      notify(("运行失败（退出码 %d）：\n%s"):format(result.code, vim.trim(output or "")), vim.log.levels.ERROR)
      return false
    end
    return true
  end

  vim.opt.splitbelow = true
  vim.cmd("botright 15new")
  local job = vim.fn.jobstart(command, { cwd = cwd, term = true })
  if job <= 0 then
    notify("无法启动终端命令：" .. vim.inspect(command), vim.log.levels.ERROR)
    return false
  end
  vim.cmd("startinsert")
  return true
end

local function compile(command, cwd)
  command = vim.deepcopy(command)
  command[1] = executable(command[1])
  if not command[1] then
    return false
  end

  local result = vim.system(command, { cwd = cwd, text = true }):wait()
  if result.code == 0 then
    return true
  end

  local output = result.stderr ~= "" and result.stderr or result.stdout
  notify(("编译失败（退出码 %d）：\n%s"):format(result.code, vim.trim(output or "")), vim.log.levels.ERROR)
  return false
end

function M.spec(filetype, file)
  file = vim.fs.normalize(file)
  local cwd = vim.fs.dirname(file)
  local stem = vim.fn.fnamemodify(file, ":r")
  local output = stem .. (is_win and ".exe" or "")

  if filetype == "c" then
    return { cwd = cwd, compile = { "gcc", file, "-o", output }, run = { output } }
  elseif filetype == "cpp" then
    return { cwd = cwd, compile = { "g++", "-std=c++11", file, "-Wall", "-o", output }, run = { output } }
  elseif filetype == "cs" then
    return { cwd = cwd, compile = { "mcs", file, "-out:" .. stem .. ".exe" }, run = { "mono", stem .. ".exe" } }
  elseif filetype == "java" then
    return {
      cwd = cwd,
      compile = { "javac", file },
      run = { "java", "-cp", cwd, vim.fn.fnamemodify(file, ":t:r") },
    }
  elseif filetype == "sh" then
    return { cwd = cwd, run = { "bash", file } }
  elseif filetype == "python" then
    local python = is_win and "python" or "python3"
    if vim.fn.executable(python) ~= 1 then
      python = is_win and "python3" or "python"
    end
    return { cwd = cwd, run = { python, file } }
  elseif filetype == "html" then
    return { open = file }
  elseif filetype == "markdown" or filetype == "vimwiki" then
    return { command = "MarkdownPreview" }
  elseif filetype == "tex" then
    return { commands = { "VimtexStop", "VimtexCompile" } }
  elseif filetype == "dart" then
    local device = vim.g.flutter_default_device or ""
    local args = vim.g.flutter_run_args or ""
    return { commands = { "CocCommand flutter.run -d " .. device .. " " .. args, "CocCommand flutter.dev.openDevLog" } }
  elseif filetype == "javascript" then
    return { cwd = cwd, run = { "node", "--trace-warnings", file } }
  elseif filetype == "racket" then
    return { cwd = cwd, run = { "racket", file } }
  elseif filetype == "go" then
    return { cwd = cwd, run = { "go", "run", "." } }
  end
end

function M.run_current()
  if vim.bo.buftype ~= "" then
    notify("当前缓冲区不是普通文件", vim.log.levels.WARN)
    return false
  end

  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    notify("请先保存当前文件", vim.log.levels.WARN)
    return false
  end

  vim.cmd("write")
  local spec = M.spec(vim.bo.filetype, file)
  if not spec then
    notify("未配置一键运行命令的文件类型：" .. vim.bo.filetype, vim.log.levels.WARN)
    return false
  end

  if spec.compile and not compile(spec.compile, spec.cwd) then
    return false
  end
  if spec.run then
    return terminal(spec.run, spec.cwd)
  end
  if spec.open then
    local _, err = vim.ui.open(spec.open)
    if err then
      notify("无法打开文件：" .. tostring(err), vim.log.levels.ERROR)
      return false
    end
    return true
  end
  if spec.command then
    vim.cmd(spec.command)
    return true
  end
  if spec.commands then
    for _, command in ipairs(spec.commands) do
      local name = command:match("^%S+")
      if vim.fn.exists(":" .. name) ~= 2 then
        notify("当前配置未提供命令：" .. name, vim.log.levels.WARN)
        return false
      end
      vim.cmd(command)
    end
    return true
  end
  return false
end

return M
