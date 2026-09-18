local M = {}

function M.connections()
  return require("config.sql-credentials").connections()
end

function M.current_connection(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local url = vim.b[bufnr].sql_connection_url
  if url and url ~= "" then
    return {
      name = vim.b[bufnr].sql_connection_name or "当前连接",
      url = url,
    }
  end
end

function M.select_connection(on_select)
  local items = M.connections()
  local source_buf = vim.api.nvim_get_current_buf()

  if #items == 0 then
    vim.notify(
      "没有找到完整的数据库普通连接参数（USER/HOST/PORT/NAME）",
      vim.log.levels.ERROR
    )
    return
  end

  vim.ui.select(items, {
    prompt = "选择当前 SQL 文件使用的数据库：",

    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if not choice then
      return
    end

    if vim.api.nvim_buf_is_valid(source_buf) then
      vim.b[source_buf].sql_connection_name = choice.name
      vim.b[source_buf].sql_connection_url = choice.url
    end

    vim.notify(
      "当前 SQL 连接：" .. choice.name,
      vim.log.levels.INFO
    )
    if on_select then
      on_select(choice)
    end
  end)
end

function M.with_connection(callback)
  local current = M.current_connection()
  if current then
    callback(current)
    return
  end
  M.select_connection(callback)
end

local function open_exact_query(sql, url, opts)
  local query = require("dadbod-grip.query")
  local grip = require("dadbod-grip")
  local view = require("dadbod-grip.view")
  local cleaned_sql = sql and sql:gsub(";%s*$", "") or sql

  local original_build_sql = query.build_sql
  local original_page_info = query.page_info

  -- Dadbod Grip 默认会把原始 SELECT 包成子查询后再追加分页 LIMIT。
  -- <leader>sr 要严格执行用户写下的查询，因此首轮查询直接交给数据库。
  query.build_sql = function(spec, build_opts)
    if spec.is_raw
        and spec.base_sql == cleaned_sql
        and #(spec.filters or {}) == 0
        and #(spec.sorts or {}) == 0
        and (spec.page or 1) == 1 then
      return spec.base_sql
    end
    return original_build_sql(spec, build_opts)
  end

  -- 首次渲染时就把原始查询视为一个完整结果集，避免显示成“第 1/N 页”。
  query.page_info = function(spec, total_rows)
    if spec.is_raw and spec.base_sql == cleaned_sql and total_rows ~= nil then
      return ("Page 1/1 (%d rows)"):format(total_rows)
    end
    return original_page_info(spec, total_rows)
  end

  local ok, err = xpcall(function()
    grip.open(sql, url, opts)
  end, debug.traceback)

  query.build_sql = original_build_sql
  query.page_info = original_page_info

  if not ok then return false, err end

  -- open() 是同步的，返回后当前 buffer 已经是结果表。把分页大小同步成
  -- 实际取得的行数，后续本地排序/重绘时仍保持“完整结果集”的语义。
  local result_buf = vim.api.nvim_get_current_buf()
  local session = view._sessions[result_buf]
  if session
      and session.state
      and session.query_spec
      and session.query_spec.is_raw
      and session.query_spec.base_sql == cleaned_sql then
    local row_count = #(session.state.rows or {})
    session.query_spec.page = 1
    session.query_spec.page_size = math.max(row_count, 1)
    session.total_rows = row_count
  end

  return true
end

M._open_exact_query = open_exact_query

function M.run(sql)
  local source_buf = vim.api.nvim_get_current_buf()
  local current = M.current_connection()
  local url = current and current.url

  if not url then
    vim.notify(
      "当前 SQL 文件还没有选择数据库，请先按 <leader>sc",
      vim.log.levels.WARN
    )
    return
  end

  if not sql or sql:match("^%s*$") then
    vim.notify(
      "没有可执行的 SQL",
      vim.log.levels.WARN
    )
    return
  end

  local ok, err = open_exact_query(sql, url, {
    source_path = vim.api.nvim_buf_get_name(source_buf),
  })
  if not ok then
    vim.notify("SQL 执行失败：" .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.run_buffer()
  local lines = vim.api.nvim_buf_get_lines(
    0,
    0,
    -1,
    false
  )

  M.run(table.concat(lines, "\n"))
end

function M.run_visual()
  local start_line = vim.fn.line("'<") - 1
  local end_line = vim.fn.line("'>")

  local lines = vim.api.nvim_buf_get_lines(
    0,
    start_line,
    end_line,
    false
  )

  M.run(table.concat(lines, "\n"))
end

return M
