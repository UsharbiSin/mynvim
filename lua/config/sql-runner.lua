local M = {}

local connection_defs = {
  { name = "tongyan",          suffix = "TY" },
  { name = "tongyan_test",     suffix = "TYTEST" },
  { name = "platform_st",      suffix = "ST" },
  { name = "platform_st_test", suffix = "STTEST" },
}

local function get_connection(item)
  local suffix = item.suffix

  for _, field in ipairs({
    "USER",
    "PASSWORD",
    "HOST",
    "PORT",
    "NAME",
  }) do
    local value = os.getenv("DB_" .. field .. "_" .. suffix)

    if not value or value == "" then
      return nil
    end
  end

  return {
    name = item.name,

    -- 保留环境变量占位符，由 Dadbod Grip 在真正连接时展开。
    url = string.format(
      "mysql://${DB_USER_%s}:${DB_PASSWORD_%s}@${DB_HOST_%s}:${DB_PORT_%s}/${DB_NAME_%s}",
      suffix,
      suffix,
      suffix,
      suffix,
      suffix
    ),
  }
end

local function connections()
  local result = {}

  for _, item in ipairs(connection_defs) do
    local conn = get_connection(item)

    if conn then
      table.insert(result, conn)
    end
  end

  return result
end

function M.select_connection()
  local items = connections()

  if #items == 0 then
    vim.notify(
      "没有找到完整的数据库环境变量",
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

    vim.b.sql_connection_name = choice.name
    vim.b.sql_connection_url = choice.url

    vim.notify(
      "当前 SQL 连接：" .. choice.name,
      vim.log.levels.INFO
    )
  end)
end

function M.run(sql)
  local url = vim.b.sql_connection_url

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

  require("dadbod-grip").open(sql, url)
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
