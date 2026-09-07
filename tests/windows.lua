-- D:\Neovim\bin\nvim.exe --headless -u init.lua -l tests/windows.lua
local tmp = vim.fn.tempname() .. " path"
local checks = 0

local function check(value, message)
  assert(value, message)
  checks = checks + 1
end

local function run_file(name, lines, filetype)
  local file = vim.fs.joinpath(tmp, name)
  vim.fn.writefile(lines, file)
  vim.cmd("edit! " .. vim.fn.fnameescape(file))
  vim.bo.filetype = filetype
  check(require("core.runner").run_current(), filetype .. " runner must finish successfully")
end

local function test()
  check(vim.fn.has("win32") == 1, "this test requires native Windows Neovim")
  vim.fn.mkdir(tmp, "p")

  local runner = require("core.runner")
  local base = vim.fs.joinpath(tmp, "source file")
  local c = assert(runner.spec("c", base .. ".c"))
  check(c.compile[2] == base .. ".c", "C source path must remain one argv item")
  check(c.run[1] == base .. ".exe", "C output must use a Windows executable path")
  local markdown = assert(runner.spec("markdown", base .. ".md"))
  check(markdown.command == "MarkdownPreview", "Markdown must use the installed preview command")
  local html = assert(runner.spec("html", base .. ".html"))
  check(html.open == base .. ".html", "HTML must use the system opener")
  local python = assert(runner.spec("python", base .. ".py"))
  check(python.run[2] == base .. ".py", "Python source path must remain one argv item")

  local sqls = dofile(vim.fs.joinpath(vim.fn.getcwd(), "lsp", "sqls.lua"))
  check(
    #sqls.settings.sqls.connections == 0,
    "SQL connections must be omitted when their environment variables are incomplete"
  )

  local sql_file = vim.fs.joinpath(tmp, "query.sql")
  vim.fn.writefile({ "select 1;" }, sql_file)
  vim.cmd("edit! " .. vim.fn.fnameescape(sql_file))
  vim.bo.filetype = "sql"
  check(vim.wait(10000, function()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
      if client.name == "sqls" then
        return true
      end
    end
    return false
  end, 50), "sqls must attach without database environment variables")

  run_file("hello world.c", {
    "#include <stdio.h>",
    "int main(void) { puts(\"runner-c-ok\"); return 0; }",
  }, "c")
end

local ok, err = xpcall(test, debug.traceback)
vim.cmd("silent! %bwipeout!")
vim.fn.delete(tmp, "rf")

if not ok then
  print("FAIL: " .. tostring(err))
  vim.cmd("cquit 1")
else
  print(("PASS: %d Windows configuration checks"):format(checks))
  vim.cmd("qa!")
end
