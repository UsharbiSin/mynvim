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

  local im_select_events = {}
  for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = "im-select" })) do
    im_select_events[autocmd.event] = true
  end
  check(im_select_events.InsertLeave, "im-select must switch to English after leaving Insert mode")
  check(not im_select_events.CmdlineLeave, "im-select must ignore expression-register CmdlineLeave events")

  local vimwiki_file = vim.fs.joinpath(tmp, "notes.md")
  vim.fn.writefile({ "- first item" }, vimwiki_file)
  vim.cmd("edit! " .. vim.fn.fnameescape(vimwiki_file))
  check(vim.bo.filetype == "vimwiki", "Markdown files must exercise the active Vimwiki configuration")

  local insert_leaves = 0
  local cmdline_leaves = 0
  local observed_insert_leaves
  local observed_cmdline_leaves
  local event_group = vim.api.nvim_create_augroup("MarkdownEnterEventsTest", { clear = true })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = event_group,
    callback = function()
      insert_leaves = insert_leaves + 1
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = event_group,
    callback = function()
      cmdline_leaves = cmdline_leaves + 1
    end,
  })
  vim.keymap.set("i", "<F20>", function()
    observed_insert_leaves = insert_leaves
    observed_cmdline_leaves = cmdline_leaves
  end, { buffer = true })
  local enter_keys = vim.api.nvim_replace_termcodes("A<CR><F20>", true, false, true)
  vim.fn.feedkeys(enter_keys, "xt")
  vim.api.nvim_del_augroup_by_id(event_group)
  check(observed_insert_leaves == 0, "Markdown Enter must remain in Insert mode")
  check(observed_cmdline_leaves == 1, "Markdown Enter must exercise bullets.vim's expression register")

  local markdown_file = vim.fs.joinpath(tmp, "input.md")
  vim.fn.writefile({ "| first | second |" }, markdown_file)
  vim.cmd("edit! " .. vim.fn.fnameescape(markdown_file))
  check(vim.bo.filetype == "vimwiki", "Table Mode must exercise the actual Markdown filetype")
  vim.cmd("TableModeToggle")
  local cr_map = vim.fn.maparg("<CR>", "i", false, true)
  check(type(cr_map.callback) == "function", "Markdown table mode must install its Enter callback")
  local pipe_map = vim.fn.maparg("|", "i", false, true)
  check(type(pipe_map.rhs) == "string" and pipe_map.rhs ~= "", "Table Mode must install a safe pipe mapping")

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local table_insert_leaves = 0
  local observed_table_insert_leaves
  local observed_header_lines
  local table_event_group = vim.api.nvim_create_augroup("TableModeEnterEventsTest", { clear = true })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = table_event_group,
    callback = function()
      table_insert_leaves = table_insert_leaves + 1
    end,
  })
  vim.keymap.set("i", "<F20>", function()
    observed_table_insert_leaves = table_insert_leaves
    observed_header_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end, { buffer = true })
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes("i||||<CR><F20>", true, false, true), "xt")
  vim.api.nvim_del_augroup_by_id(table_event_group)
  check(observed_table_insert_leaves == 0, "Table Mode Enter must remain in Insert mode")
  check(observed_header_lines[1] == "| <++> | <++> | <++> |", "Empty header cells must receive placeholders")
  check(observed_header_lines[2] == "|---|---|---|", "Markdown header Enter must preserve every column")
  check(observed_header_lines[3] == "| <++> | <++> | <++> |", "Markdown header Enter must create a matching data row")

  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "| first | second |",
    "|---|---|",
    "| value | value ||",
  })
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  check(not pipe_map.rhs:find("<Esc>", 1, true), "Table Mode pipe mapping must remain in Insert mode")
  require("config.vim-table-mode").sync_current()
  local synchronized_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  check(synchronized_lines[1] == "| first | second | <++> |", "Adding a separator must extend the header")
  check(synchronized_lines[2] == "|---|---|---|", "Adding a separator must extend the border")
  check(synchronized_lines[3] == "| value | value | <++> |", "Adding a separator must fill the current cell")

  local function table_enter(lines, row)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    local ok, err = pcall(cr_map.callback)
    assert(ok, err)
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  local extended_lines = table_enter({
    "| first | second |",
    "|---|---|",
    "| value | value | added |",
  }, 3)
  check(extended_lines[1] == "| first | second | <++> |", "Adding a data column must extend the header")
  check(extended_lines[2] == "|---|---|---|", "Adding a data column must extend the separator")
  check(extended_lines[4] == "| <++> | <++> | <++> |", "Table Enter must use the synchronized column count")
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
