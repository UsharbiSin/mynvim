-- nvim --headless -u NONE -l tests/codex.lua
local repo = vim.fn.getcwd()
local snacks = vim.env.SNACKS_RTP or (vim.fn.stdpath("data") .. "/lazy/snacks.nvim")
vim.opt.rtp:prepend(repo)
vim.opt.rtp:prepend(snacks)
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
vim.g.mapleader = " "
require("core.options")
require("core.keymaps")
require("config.snacks")
local codex = require("config.codex")
local tmp = vim.fn.tempname()
local terminals = {}
local checks = 0

local function check(value, message)
  assert(value, message)
  checks = checks + 1
end

local function edit(path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end

local function test()
  vim.fn.mkdir(tmp .. "/project one/.git", "p")
  vim.fn.mkdir(tmp .. "/project one/src/deep", "p")
  vim.fn.mkdir(tmp .. "/project two", "p")
  vim.fn.writefile({ "gitdir: ../project one/.git/worktrees/two" }, tmp .. "/project two/.git")
  local file1 = tmp .. "/project one/src/a.lua"
  local file2 = tmp .. "/project one/src/deep/b.lua"
  local file3 = tmp .. "/project two/c.lua"
  for _, file in ipairs({ file1, file2, file3 }) do
    vim.fn.writefile({ "original" }, file)
  end
  local buf1 = edit(file1)
  local root1 = vim.fs.normalize(tmp .. "/project one")
  check(codex.root() == root1, "must use repository root with autochdir")
  edit(file2)
  check(codex.root() == root1, "nested files must share a root")
  edit(file3)
  check(codex.root() == vim.fs.normalize(tmp .. "/project two"), "must recognize a worktree .git file")
  vim.fn.writefile({ "standalone" }, tmp .. "/loose.lua")
  edit(tmp .. "/loose.lua")
  check(codex.root() == vim.fs.normalize(tmp), "non-repository file must use its directory")

  -- 每个模拟仅替换操作系统查询；其余使用真实 Neovim API。
  local original = { has = vim.fn.has, exepath = vim.fn.exepath, filereadable = vim.fn.filereadable }
  local resolver_ok, resolver_err = xpcall(function()
    vim.fn.has = function(name) return name == "win32" and 1 or original.has(name) end
    local js = "C:/Users/Test User/npm/node_modules/@openai/codex/bin/codex.js"
    vim.fn.exepath = function(name)
      local paths = {
        codex = "C:/Users/Test User/npm/codex.cmd",
        node = "C:/Program Files/nodejs/node.exe",
        ["C:/Users/Test User/npm/codex.cmd"] = "C:/Users/Test User/npm/codex.cmd",
      }
      return paths[name] or ""
    end
    vim.fn.filereadable = function(path) return path == js and 1 or 0 end
    local cmd = assert(codex.command())
    check(vim.deep_equal(cmd, { "C:/Program Files/nodejs/node.exe", js }), "npm shim must use argv via node")
    vim.fn.filereadable = function() return 0 end
    check(codex.command() == nil, "broken npm installation must fail with a diagnostic")
    vim.fn.exepath = function(name)
      if name == "codex.exe" or name == "C:/Tools/Codex/codex.exe" then
        return "C:/Tools/Codex/codex.exe"
      end
      return ""
    end
    check(vim.deep_equal(codex.command(), { "C:/Tools/Codex/codex.exe" }), "native Windows executable must work")
  end, debug.traceback)
  for name, fn in pairs(original) do vim.fn[name] = fn end
  assert(resolver_ok, resolver_err)
  vim.g.codex_cmd = "codex --model test"
  check(codex.command() == nil, "shell command strings must be rejected")
  vim.g.codex_cmd = { "mynvim-test-missing-codex-executable" }
  check(codex.command() == nil, "missing executable must fail without opening a terminal")

  -- 使用 Neovim 子进程模拟 CLI；无需登录，不发起网络/模型请求。
  local fake = tmp .. "/fake cli.lua"
  local log = tmp .. "/cli.json"
  vim.fn.writefile({
    "vim.fn.writefile({ vim.json.encode({ cwd = vim.fn.getcwd(), argv = vim.v.argv }) }, " .. string.format("%q", log) .. ")",
    "vim.wait(20000, function() return false end, 50)",
    "vim.cmd('qa!')",
  }, fake)
  vim.g.codex_cmd = { vim.v.progpath, "--headless", "-u", "NONE", "-l", fake }
  edit(file1)
  vim.cmd("Codex")
  local first
  for _, terminal in ipairs(Snacks.terminal.list()) do first = terminal end
  assert(first, "Codex command must open a terminal")
  terminals[#terminals + 1] = first
  check(vim.wait(5000, function() return vim.fn.filereadable(log) == 1 end, 20), "CLI must start")
  local child = vim.json.decode(table.concat(vim.fn.readfile(log)))
  check(vim.fs.normalize(child.cwd) == root1, "CLI process cwd must be project root")
  check(child.argv[#child.argv] == "--no-alt-screen", "CLI must receive terminal option")
  check(codex.root(first.buf) == root1, "terminal buffer must retain project identity")
  codex.toggle()
  check(not first:win_valid(), "toggle must hide terminal")
  check(vim.fn.jobwait({ vim.b[first.buf].terminal_job_id }, 0)[1] == -1, "hiding must keep the job alive")
  edit(file2)
  check(codex.toggle() == first, "other subdirectory must reuse the same terminal")
  check(codex.resume() == first, "resume must not duplicate a running project session")

  first:hide()
  edit(file3)
  local second = assert(codex.toggle())
  terminals[#terminals + 1] = second
  check(second.buf ~= first.buf, "different repositories need independent sessions")
  second:close()
  vim.wait(100, function() return not second:buf_valid() end, 10)
  vim.fn.delete(log)
  edit(file3)
  local resumed = assert(codex.resume())
  terminals[#terminals + 1] = resumed
  check(vim.wait(5000, function() return vim.fn.filereadable(log) == 1 end, 20), "resume process must start")
  child = vim.json.decode(table.concat(vim.fn.readfile(log)))
  check(child.argv[#child.argv] == "resume", "resume command must select CLI history")
  resumed:hide()

  edit(file1)
  vim.fn.writefile({ "changed externally", "new line" }, file1)
  vim.api.nvim_exec_autocmds("FocusGained", {})
  check(vim.wait(1000, function() return vim.api.nvim_buf_get_lines(buf1, 0, 1, false)[1] == "changed externally" end),
    "focus event must reload clean buffers")
  vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "unsaved local changes" })
  vim.fn.writefile({ "a conflicting external edit" }, file1)
  codex.refresh()
  check(vim.bo[buf1].modified and vim.api.nvim_buf_get_lines(buf1, 0, 1, false)[1] == "unsaved local changes",
    "refresh must preserve unsaved local edits")
  vim.bo[buf1].modified = false
  check(vim.fn.maparg("<Space>ac", "n") ~= "", "toggle mapping must exist")
  check(vim.fn.maparg("<Space>ar", "n") ~= "", "resume mapping must exist")
  check(vim.fn.maparg("<C-t>", "t") ~= "", "existing terminal escape must remain available")
  vim.cmd("checkhealth codex")
  local health = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  check(health:find("Codex CLI 集成", 1, true) ~= nil, "checkhealth must discover the Codex module")
  check(not health:find("ERROR", 1, true), "healthcheck must load successfully")
  codex.setup()
  check(#vim.api.nvim_get_autocmds({ group = "CodexRefresh" }) == 3, "setup must not duplicate autocmds")
end

local ok, err = xpcall(test, debug.traceback)
for _, terminal in ipairs(terminals) do pcall(function() terminal:close() end) end
vim.g.codex_cmd = nil
vim.fn.chdir(repo)
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_get_name(buf):sub(1, #tmp) == tmp then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end
vim.fn.delete(tmp, "rf")
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
else
  print(("PASS: %d Codex integration checks"):format(checks))
  vim.cmd("qa!")
end
