local M = {}

local metadata = require("config.sql-metadata")
local namespace = vim.api.nvim_create_namespace("SqlCommentBrowser")
local state = {
  bufnr = nil,
  winid = nil,
  source_win = nil,
  url = nil,
  connection_name = nil,
  tables = {},
  visible = {},
  nodes = {},
  expanded = {},
  filter = "",
}

local function valid_win(winid)
  return winid and vim.api.nvim_win_is_valid(winid)
end

local function current_node()
  return state.nodes[vim.api.nvim_win_get_cursor(0)[1]]
end

local function close()
  if valid_win(state.winid) then
    vim.api.nvim_win_close(state.winid, true)
  end
  state.bufnr, state.winid = nil, nil
end

local function render()
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    return
  end

  state.visible = metadata.filter(state.tables, state.filter)
  state.nodes = {}
  local lines = {}
  local comments = {}

  if state.filter ~= "" then
    table.insert(lines, "筛选：" .. state.filter)
    comments[#lines] = "按 F 清除"
  end

  for _, item in ipairs(state.visible) do
    local expanded = state.expanded[item.name]
    local marker = expanded and "▾ " or "▸ "
    table.insert(lines, marker .. item.name)
    state.nodes[#lines] = { kind = "table", value = item }
    comments[#lines] = item.comment ~= "" and item.comment or (item.type == "view" and "视图" or "")

    if expanded then
      for _, column in ipairs(item.columns) do
        table.insert(lines, "    " .. column.name .. "  " .. column.type)
        state.nodes[#lines] = { kind = "column", value = column, parent = item }
        comments[#lines] = column.comment
      end
    end
  end

  if #state.visible == 0 then
    table.insert(lines, "没有匹配的数据表")
  end

  vim.bo[state.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(state.bufnr, namespace, 0, -1)
  for line, comment in pairs(comments) do
    if comment and comment ~= "" then
      vim.api.nvim_buf_set_extmark(state.bufnr, namespace, line - 1, 0, {
        virt_text = { { "  " .. comment, "Comment" } },
        virt_text_pos = "eol",
      })
    end
  end
  vim.bo[state.bufnr].modifiable = false
end

local function show_node_comment()
  local node = current_node()
  if not node then
    return
  end
  local item = node.kind == "table" and node.value or node.parent
  local lines = {
    "# " .. item.name,
    item.comment ~= "" and item.comment or "（无表注释）",
    "",
  }
  for _, column in ipairs(item.columns) do
    local comment = column.comment ~= "" and column.comment or "（无注释）"
    table.insert(lines, ("- `%s` · %s：%s"):format(column.name, column.type, comment))
  end
  vim.lsp.util.open_floating_preview(lines, "markdown", { border = "rounded" })
end

local function open_table(item)
  if valid_win(state.source_win) then
    vim.api.nvim_set_current_win(state.source_win)
  end
  require("dadbod-grip").open(item.name, state.url)
end

local function set_keymaps()
  local opts = { buffer = state.bufnr, silent = true }
  vim.keymap.set("n", "q", close, opts)
  vim.keymap.set("n", "<Esc>", close, opts)
  vim.keymap.set("n", "<CR>", function()
    local node = current_node()
    if not node then return end
    open_table(node.kind == "table" and node.value or node.parent)
  end, opts)
  vim.keymap.set("n", "l", function()
    local node = current_node()
    if not node then return end
    local item = node.kind == "table" and node.value or node.parent
    state.expanded[item.name] = true
    render()
  end, opts)
  vim.keymap.set("n", "h", function()
    local node = current_node()
    if not node then return end
    local item = node.kind == "table" and node.value or node.parent
    state.expanded[item.name] = nil
    render()
  end, opts)
  vim.keymap.set("n", "K", show_node_comment, opts)
  vim.keymap.set("n", "/", function()
    vim.ui.input({ prompt = "按表名或中文注释筛选：", default = state.filter }, function(value)
      if value == nil then return end
      state.filter = value
      render()
    end)
  end, opts)
  vim.keymap.set("n", "F", function()
    state.filter = ""
    render()
  end, opts)
  vim.keymap.set("n", "r", function()
    local tables, err = metadata.fetch(state.url, true)
    if not tables then
      vim.notify("SQL 表浏览器：" .. err, vim.log.levels.ERROR)
      return
    end
    state.tables = tables
    render()
  end, opts)
end

local function open_for_connection(connection)
  local tables, err = metadata.fetch(connection.url)
  if not tables then
    vim.notify("SQL 表浏览器：" .. err, vim.log.levels.ERROR)
    return
  end

  state.source_win = vim.api.nvim_get_current_win()
  state.url = connection.url
  state.connection_name = connection.name
  state.tables = tables
  state.filter = ""
  state.expanded = {}

  vim.cmd("topleft 38vnew")
  state.winid = vim.api.nvim_get_current_win()
  state.bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(state.bufnr, "SQL 表与注释 [" .. connection.name .. "]")
  vim.bo[state.bufnr].buftype = "nofile"
  vim.bo[state.bufnr].bufhidden = "wipe"
  vim.bo[state.bufnr].swapfile = false
  vim.bo[state.bufnr].filetype = "sql_metadata"
  vim.wo[state.winid].number = false
  vim.wo[state.winid].relativenumber = false
  vim.wo[state.winid].wrap = false
  set_keymaps()
  render()
end

function M.toggle()
  if valid_win(state.winid) then
    if vim.api.nvim_get_current_win() == state.winid then
      close()
    else
      vim.api.nvim_set_current_win(state.winid)
    end
    return
  end
  require("config.sql-runner").with_connection(open_for_connection)
end

function M.show_result_comments()
  local view = require("dadbod-grip.view")
  local session = view._sessions[vim.api.nvim_get_current_buf()]
  if not session or not session.state then
    vim.notify("当前窗口不是 Dadbod Grip 查询结果", vim.log.levels.WARN)
    return
  end

  local tables, err = metadata.fetch(session.url)
  if not tables then
    vim.notify("SQL 列注释：" .. err, vim.log.levels.ERROR)
    return
  end

  local render_state = session._render
  local columns = render_state
      and (render_state.visible_columns or session.state.columns)
      or session.state.columns
  local cursor = vim.api.nvim_win_get_cursor(0)
  local column = render_state
      and view._resolve_col_at(render_state, columns, cursor[1], cursor[2])
      or nil
  if not column then
    vim.notify("当前光标不在查询结果字段上", vim.log.levels.WARN)
    return
  end

  local comments = metadata.column_comments(
    tables,
    { column },
    session.state.table_name
  )
  local lines = { "# " .. column, "" }
  if #comments == 0 then
    table.insert(lines, "当前字段没有可用的数据库注释。")
  else
    for _, item in ipairs(comments) do
      table.insert(lines, ("- `%s.%s` · `%s`：%s"):format(
        item.table_name,
        item.column_name,
        item.type ~= "" and item.type or "未知类型",
        item.comment
      ))
    end
  end
  vim.lsp.util.open_floating_preview(lines, "markdown", { border = "rounded" })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("SqlResultComments", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(event)
      -- Grip 会在打开网格的后半段创建默认 K 映射，延迟到本轮事件结束后再覆盖。
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(event.buf) then return end
        local ok, view = pcall(require, "dadbod-grip.view")
        if not ok or not view._sessions[event.buf] then return end
        vim.keymap.set("n", "K", M.show_result_comments, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：显示光标所在字段的类型和注释",
        })
      end)
    end,
  })
end

return M
