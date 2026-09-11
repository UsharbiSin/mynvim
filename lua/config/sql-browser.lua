local M = {}

local metadata = require("config.sql-metadata")
local namespace = vim.api.nvim_create_namespace("SqlCommentBrowser")
local result_column_orders = {}
local result_cleanup_registered = {}
local export_in_progress = {}
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

local function merge_column_order(saved, current)
  local available = {}
  for _, column in ipairs(current or {}) do
    available[column] = true
  end

  local ordered = {}
  for _, column in ipairs(saved or {}) do
    if available[column] then
      table.insert(ordered, column)
      available[column] = nil
    end
  end
  for _, column in ipairs(current or {}) do
    if available[column] then
      table.insert(ordered, column)
      available[column] = nil
    end
  end
  return ordered
end

local function reorder_result_state(state, desired_order)
  local current = state.columns or {}
  local ordered = merge_column_order(desired_order, current)

  -- 当前字段名对应当前 rows 中的物理位置。
  local source_index = {}
  for index, column in ipairs(current) do
    source_index[column] = index
  end

  -- columns 改顺序时，rows 必须按完全相同的顺序一起重排。
  local rows = {}
  for row_index, row in ipairs(state.rows or {}) do
    local reordered_row = {}
    for column_index, column in ipairs(ordered) do
      reordered_row[column_index] = row[source_index[column]]
    end
    rows[row_index] = reordered_row
  end

  -- 不原地修改 dadbod-grip 的 columns/rows。
  -- 新建 state，并保留 changes/deleted/inserted 等其它状态。
  local next_state = {}
  for key, value in pairs(state) do
    next_state[key] = value
  end

  next_state.columns = ordered
  next_state.rows = rows

  return next_state
end

local function restore_result_column_order(bufnr, view)
  local saved = result_column_orders[bufnr]
  local session = view._sessions[bufnr]
  if not saved or not session or not session.state then return end

  local next_state = reorder_result_state(session.state, saved)
  view.render(bufnr, next_state)
end

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

function M.reorder_result_column(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local view = require("dadbod-grip.view")
  local session = view._sessions[bufnr]
  if not session or not session.state or not session._render then
    vim.notify("当前窗口不是 Dadbod Grip 查询结果", vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local visible = session._render.visible_columns or session.state.columns
  local column = view._resolve_col_at(session._render, visible, cursor[1], cursor[2])
  if not column then
    vim.notify("请先把光标移到需要调整的列", vim.log.levels.INFO)
    return
  end

  local visible_index
  for index, name in ipairs(visible) do
    if name == column then
      visible_index = index
      break
    end
  end
  local adjacent = visible[visible_index and (visible_index + direction) or 0]
  if not adjacent then
    vim.notify(direction < 0 and "当前列已经在最左侧" or "当前列已经在最右侧", vim.log.levels.INFO)
    return
  end

  local column_index, adjacent_index
  for index, name in ipairs(session.state.columns) do
    if name == column then column_index = index end
    if name == adjacent then adjacent_index = index end
  end
  if not column_index or not adjacent_index then return end

  local next_order = vim.deepcopy(session.state.columns)

  next_order[column_index], next_order[adjacent_index] =
      next_order[adjacent_index], next_order[column_index]

  local next_state = reorder_result_state(session.state, next_order)

  result_column_orders[bufnr] = vim.deepcopy(next_state.columns)
  view.render(bufnr, next_state)

  local render = session._render
  local positions
  if cursor[1] == 2 then
    positions = render.hdr_byte_positions
  elseif render.type_row_byte_positions and cursor[1] == 3 then
    positions = render.type_row_byte_positions
  elseif cursor[1] >= render.data_start then
    positions = render.byte_positions[cursor[1] - render.data_start + 1]
  end
  local target = positions and positions[column]
  if target then
    vim.api.nvim_win_set_cursor(0, { cursor[1], target.start })
  end
end

local function resize_width(width, delta)
  return math.max(6, math.min(200, (width or 10) + delta))
end

function M.resize_result_column(delta)
  local bufnr = vim.api.nvim_get_current_buf()
  local view = require("dadbod-grip.view")
  local session = view._sessions[bufnr]
  if not session or not session._render then
    vim.notify("当前窗口没有可调整宽度的结果表", vim.log.levels.WARN)
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local visible = session._render.visible_columns or session.state.columns
  local column = view._resolve_col_at(session._render, visible, cursor[1], cursor[2])
  if not column then
    vim.notify("请先把光标移到需要调整宽度的列", vim.log.levels.INFO)
    return
  end
  session.col_width_overrides = session.col_width_overrides or {}
  local current = session._render.widths and session._render.widths[column]
  session.col_width_overrides[column] = resize_width(
    session.col_width_overrides[column] or current,
    delta
  )
  view.render(bufnr, session.state)
end

M._resize_width = resize_width

local function export_rows(state)
  local data = require("dadbod-grip.data")
  local rows = {}
  for _, row_index in ipairs(data.get_ordered_rows(state)) do
    if not state.deleted[row_index] then
      local row = {}
      for _, column in ipairs(state.columns or {}) do
        row[#row + 1] = data.effective_value(state, row_index, column)
      end
      rows[#rows + 1] = row
    end
  end
  return rows
end

local function sanitize_export_name(name)
  name = vim.trim(tostring(name or ""))
  name = name:gsub("[<>:\"/\\|%?%*%c]", "_")
  name = name:gsub("[%. ]+$", "")
  return name ~= "" and name or "查询结果"
end

local function export_default_path(session, format)
  local table_name = session.state and session.state.table_name
    or session.query_spec and session.query_spec.table_name
  local source_path = session.opts and session.opts.source_path
  local name = table_name
  if not name and source_path and source_path ~= "" then
    name = vim.fn.fnamemodify(source_path, ":t:r")
  end
  return vim.fs.joinpath(vim.fn.getcwd(), sanitize_export_name(name) .. "." .. format)
end

function M.export_result()
  local bufnr = vim.api.nvim_get_current_buf()
  local view = require("dadbod-grip.view")
  local session = view._sessions[bufnr]
  if not session or not session.state or #(session.state.columns or {}) == 0 then
    vim.notify("当前窗口没有可导出的查询结果", vim.log.levels.WARN)
    return
  end
  if export_in_progress[bufnr] then
    vim.notify("当前查询结果正在导出，请稍候", vim.log.levels.INFO)
    return
  end

  vim.ui.select({ "xlsx", "csv" }, { prompt = "选择查询结果导出格式：" }, function(format)
    if not format or not vim.api.nvim_buf_is_valid(bufnr) then return end
    local default = export_default_path(session, format)
    vim.ui.input({
      prompt = "导出到：",
      default = default,
      completion = "file",
    }, function(path)
      if not path or vim.trim(path) == "" or not vim.api.nvim_buf_is_valid(bufnr) then return end
      path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
      if vim.fn.fnamemodify(path, ":e"):lower() ~= format then path = path .. "." .. format end
      if vim.fn.filereadable(path) == 1 then
        local choice = vim.fn.confirm("文件已存在，是否覆盖？\n" .. path, "&覆盖\n&取消", 2)
        if choice ~= 1 then return end
      end
      local python
      for _, executable in ipairs(vim.fn.has("win32") == 1 and { "python", "python3" } or { "python3", "python" }) do
        local candidate = vim.fn.exepath(executable)
        if candidate ~= "" then python = candidate; break end
      end
      if not python then
        vim.notify("导出查询结果需要 Python 3", vim.log.levels.ERROR)
        return
      end
      local script = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "sql_export.py")
      local rows = export_rows(session.state)
      local payload = vim.json.encode({
        format = format,
        path = path,
        columns = session.state.columns,
        rows = rows,
      })
      export_in_progress[bufnr] = true
      vim.notify("正在导出查询结果……")
      vim.system({ python, script }, { text = true, stdin = payload }, function(result)
        export_in_progress[bufnr] = nil
        vim.schedule(function()
          if result.code ~= 0 then
            local message = vim.trim(result.stderr or "")
            vim.notify("查询结果导出失败：" .. (message ~= "" and message or "未知错误"), vim.log.levels.ERROR)
            return
          end
          vim.notify(("已导出 %d 行到：%s"):format(#rows, path))
        end)
      end)
    end)
  end)
end

M._export_rows = export_rows
M._export_default_path = export_default_path

function M.sort_result_column(direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local view = require("dadbod-grip.view")
  local session = view._sessions[bufnr]
  if not session or not session.query_spec or not session._render then
    vim.notify("当前窗口没有可用的列排序功能", vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local visible = session._render.visible_columns or session.state.columns
  local column = view._resolve_col_at(session._render, visible, cursor[1], cursor[2])
  if not column then
    vim.notify("请先把光标移到需要排序的列", vim.log.levels.INFO)
    return
  end

  local data = require("dadbod-grip.data")
  if data.has_changes(session.state) then
    local staged = data.count_staged(session.state)
    local choice = vim.fn.confirm(
      ("排序会放弃 %d 项尚未提交的修改，是否继续？"):format(staged),
      "&继续\n&取消",
      2
    )
    if choice ~= 1 then return end
  end

  local spec = vim.deepcopy(session.query_spec)
  local sorts = spec.sorts or {}
  local next_sorts = {}
  local found = false
  for _, sort in ipairs(sorts) do
    if sort.column == column then
      found = true
      -- 同一列再次使用相同方向时取消该排序；相反方向则更新方向。
      if sort.dir ~= direction then
        next_sorts[#next_sorts + 1] = { column = column, dir = direction }
      end
    else
      next_sorts[#next_sorts + 1] = vim.deepcopy(sort)
    end
  end
  if not found then
    -- 新列追加到 ORDER BY 末尾，保留之前列的优先级，实现联动排序。
    next_sorts[#next_sorts + 1] = { column = column, dir = direction }
  end
  spec.sorts = next_sorts
  spec.page = 1
  if session.on_requery then
    session.on_requery(bufnr, spec)
    restore_result_column_order(bufnr, view)
  end
end

M._next_sorts = function(sorts, column, direction)
  local next_sorts = {}
  local found = false
  for _, sort in ipairs(sorts or {}) do
    if sort.column == column then
      found = true
      if sort.dir ~= direction then
        next_sorts[#next_sorts + 1] = { column = column, dir = direction }
      end
    else
      next_sorts[#next_sorts + 1] = vim.deepcopy(sort)
    end
  end
  if not found then next_sorts[#next_sorts + 1] = { column = column, dir = direction } end
  return next_sorts
end

M._merge_column_order = merge_column_order

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
        if not result_cleanup_registered[event.buf] then
          result_cleanup_registered[event.buf] = true
          vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = event.buf,
            once = true,
            callback = function()
              result_column_orders[event.buf] = nil
              result_cleanup_registered[event.buf] = nil
            end,
          })
        end
        vim.keymap.set("n", "K", M.show_result_comments, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：显示光标所在字段的类型和注释",
        })
        vim.keymap.set("n", "<C-h>", function()
          M.reorder_result_column(-1)
        end, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：将当前列向左移动",
        })
        vim.keymap.set("n", "<C-l>", function()
          M.reorder_result_column(1)
        end, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：将当前列向右移动",
        })
        vim.keymap.set("n", "<C-s>", function()
          M.sort_result_column("ASC")
        end, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：按当前列升序排列",
        })
        vim.keymap.set("n", "<C-d>", function()
          M.sort_result_column("DESC")
        end, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：按当前列降序排列",
        })
        vim.keymap.set("n", "<leader>ss", function()
          M.sort_result_column("ASC")
        end, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：按当前列升序或取消升序",
        })
        vim.keymap.set("n", "<leader>sd", function()
          M.sort_result_column("DESC")
        end, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：按当前列降序或取消降序",
        })
        vim.keymap.set("n", "<leader>[", function()
          M.resize_result_column(-4)
        end, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：缩窄当前列",
        })
        vim.keymap.set("n", "<leader>]", function()
          M.resize_result_column(4)
        end, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：加宽当前列",
        })
        vim.keymap.set("n", "<leader>sx", M.export_result, {
          buffer = event.buf,
          silent = true,
          desc = "SQL：导出当前结果页为 XLSX 或 CSV",
        })
      end)
    end,
  })
end

return M
