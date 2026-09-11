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
  check(vim.o.foldmethod == "manual", "folding must wait for a syntax provider")
  check(vim.diagnostic.config().virtual_text == true, "LSP virtual text must be enabled on both platforms")

  check(
    vim.g.vimwiki_list[1].path == "E:/@home/usharbisin/vimwiki/",
    "Windows Vimwiki index must use the Linux partition"
  )

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

  local sql_env = {}
  for _, suffix in ipairs({ "TY", "TYTEST", "ST", "STTEST" }) do
    for _, field in ipairs({ "USER", "PASSWORD", "HOST", "PORT", "NAME" }) do
      local name = "DB_" .. field .. "_" .. suffix
      sql_env[name] = vim.env[name]
      vim.env[name] = nil
    end
  end
  local sqls = dofile(vim.fs.joinpath(vim.fn.getcwd(), "lsp", "sqls.lua"))
  for name, value in pairs(sql_env) do
    vim.env[name] = value
  end
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
  check(sql_client.server_capabilities.documentFormattingProvider == true, "SQLS formatting must remain available")
  local lsp_format = vim.fn.maparg("<leader>lf", "n", false, true)
  check(lsp_format.buffer == 1 and lsp_format.desc:find("LSP", 1, true), "LSP formatting must be mapped per buffer")
  local lsp_range_format = vim.fn.maparg("<leader>lf", "x", false, true)
  check(
    lsp_range_format.buffer == 1 and lsp_range_format.desc:find("选中范围", 1, true),
    "LSP range formatting must be mapped per buffer"
  )

  local sql_normal_maps = {
    ["<leader>swc"] = "SqlsSwitchConnection",
    ["<leader>swd"] = "SqlsSwitchDatabase",
    ["<leader>ssc"] = "SqlsShowConnections",
    ["<leader>ssd"] = "SqlsShowDatabases",
    ["<leader>sst"] = "SqlsShowTables",
    ["<leader>se"] = "SqlsExecuteQuery",
    ["<leader>sv"] = "SqlsExecuteQueryVertical",
  }
  for lhs, command in pairs(sql_normal_maps) do
    local mapping = vim.fn.maparg(lhs, "n", false, true)
    check(mapping.buffer == 1 and mapping.rhs:find(command, 1, true), lhs .. " must be a SQL buffer mapping")
  end
  for lhs, command in pairs({
    ["<leader>se"] = "'<,'>SqlsExecuteQuery",
    ["<leader>sv"] = "'<,'>SqlsExecuteQueryVertical",
  }) do
    local mapping = vim.fn.maparg(lhs, "x", false, true)
    check(mapping.buffer == 1 and mapping.rhs:find(command, 1, true), lhs .. " must preserve the visual line range")
  end

  for lhs, desc in pairs({
    ["<leader>st"] = "SQL：打开带中文注释的表浏览器",
  }) do
    local mapping = vim.fn.maparg(lhs, "n", false, true)
    check(mapping.desc == desc, lhs .. " must expose SQL metadata comments")
  end

  check(vim.fn.maparg("<leader>sk", "n") == "", "<leader>sk must no longer be mapped")

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

  local ime_events = {}
  for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = "windows-ime" })) do
    ime_events[autocmd.event] = true
  end
  check(ime_events.InsertEnter, "Insert mode must restore the saved Rime state")
  check(ime_events.InsertLeave, "Insert mode must save the current Rime state")
  check(ime_events.TermEnter, "Terminal mode must restore the saved Rime state")
  check(ime_events.TermLeave, "Terminal mode must save the current Rime state")
  check(not ime_events.CmdlineLeave, "expression-register evaluation must not change the IME")

  local vimwiki_file = vim.fs.joinpath(tmp, "notes.md")
  vim.fn.writefile({ "- first item" }, vimwiki_file)
  vim.cmd("edit! " .. vim.fn.fnameescape(vimwiki_file))
  check(vim.bo.filetype == "vimwiki", "Markdown files must exercise the active Vimwiki configuration")
  check(vim.wait(1000, function()
    return vim.wo.foldmethod == "expr"
      and vim.wo.foldexpr == "v:lua.vim.treesitter.foldexpr()"
  end, 10), "Tree-sitter folding setup must finish after FileType handlers")
  check(vim.wo.foldmethod == "expr", "Tree-sitter must enable syntax folds without a folding LSP")
  check(
    vim.wo.foldexpr == "v:lua.vim.treesitter.foldexpr()",
    "Tree-sitter must be the folding fallback"
  )

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

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "中文 <++> content" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local placeholder_map = vim.fn.maparg(",f", "i", false, true)
  check(type(placeholder_map.callback) == "function", "Markdown must install the Insert-mode placeholder mapping")
  placeholder_map.callback()
  check(vim.api.nvim_get_current_line() == "中文  content", "Placeholder mapping must delete the next marker")
  check(vim.api.nvim_win_get_cursor(0)[2] == #"中文 ", "Placeholder mapping must move to the deleted marker")

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "| first | second |" })
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
  local appended_line = vim.api.nvim_buf_get_lines(0, 2, 3, false)[1]
  vim.api.nvim_win_set_cursor(0, { 3, #appended_line - 1 })
  check(not pipe_map.rhs:find("<Esc>", 1, true), "Table Mode pipe mapping must remain in Insert mode")
  require("config.vim-table-mode").sync_current()
  local synchronized_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  check(synchronized_lines[1] == "| first | second | <++> |", "Adding a separator must extend the header")
  check(synchronized_lines[2] == "|---|---|---|", "Adding a separator must extend the border")
  check(synchronized_lines[3] == "| value | value | <++> |", "Adding a separator must fill the current cell")

  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "| h1 | h2 | h3 | h4 |",
    "|---|---|---|---|",
    "| v1 | v2 || v3 | v4 |",
    "| x1 | x2 | x3 | x4 |",
  })
  local middle_line = vim.api.nvim_buf_get_lines(0, 2, 3, false)[1]
  local _, inserted_pipe = middle_line:find("||", 1, true)
  -- 模拟插入模式刚输入第二个 | 后，光标位于该字符之后。
  vim.api.nvim_win_set_cursor(0, { 3, inserted_pipe })
  require("config.vim-table-mode").sync_current()
  local middle_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  check(middle_lines[1] == "| h1 | h2 | <++> | h3 | h4 |", "A middle column must extend the header in place")
  check(middle_lines[2] == "|---|---|---|---|---|", "A middle column must extend the border in place")
  check(middle_lines[4] == "| x1 | x2 | <++> | x3 | x4 |", "A middle column must extend other rows in place")

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
