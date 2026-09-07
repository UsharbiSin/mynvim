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
  local sql_client
  check(vim.wait(10000, function()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
      if client.name == "sqls" then
        sql_client = client
        return true
      end
    end
    return false
  end, 50), "sqls must attach without database environment variables")
  check(vim.fn.exists(":SqlsSwitchConnection") == 2, "sqls.nvim buffer commands must be registered")
  check(sql_client.server_capabilities.documentFormattingProvider == false, "SQLS formatting must be disabled")

  require("config.debugging")
  local dap = require("dap")
  check(dap.adapters.gdb.command == vim.fn.exepath("gdb"), "DAP must use the installed gdb executable")
  check(dap.configurations.cpp[1].type == "gdb", "C++ must prefer the available gdb DAP adapter")
  check(dap.configurations.c[1].type == "gdb", "C must provide the available gdb DAP adapter")

  require("config.markdown")
  check(vim.g.mkdp_browser == "", "Markdown preview must use the Windows default browser")
  require("config.diagram")
  local diagram_markdown = require("diagram.integrations.markdown")
  check(vim.tbl_contains(diagram_markdown.filetypes, "vimwiki"), "diagram.nvim must support Vimwiki buffers")

  local markdown_file = vim.fs.joinpath(tmp, "input.md")
  vim.fn.writefile({ "| first | second |" }, markdown_file)
  vim.cmd("edit! " .. vim.fn.fnameescape(markdown_file))
  vim.bo.filetype = "markdown"
  vim.cmd("TableModeToggle")
  local cr_map = vim.fn.maparg("<CR>", "i", false, true)
  check(type(cr_map.callback) == "function", "Markdown table mode must install its Enter callback")

  local original_feedkeys = vim.api.nvim_feedkeys
  local function table_enter_keys(lines, row)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    local captured
    vim.api.nvim_feedkeys = function(keys)
      captured = keys
    end
    local ok, err = pcall(cr_map.callback)
    vim.api.nvim_feedkeys = original_feedkeys
    assert(ok, err)
    return assert(captured, "Markdown Enter callback must feed keys")
  end

  local escape = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  local header_keys = table_enter_keys({ "| first | second |" }, 1)
  check(not header_keys:find(escape, 1, true), "Markdown header Enter must not leave Insert mode")
  local row_keys = table_enter_keys({ "| first | second |", "|---|---|" }, 2)
  check(not row_keys:find(escape, 1, true), "Markdown row Enter must not leave Insert mode")
  vim.cmd("TableModeDisable")

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
