local M = {}

local connection_defs = {
  { name = "tongyan",          suffix = "TY" },
  { name = "tongyan_test",     suffix = "TYTEST" },
  { name = "platform_st",      suffix = "ST" },
  { name = "platform_st_test", suffix = "STTEST" },
}

local function get_connection(item)
  local suffix = item.suffix

  local conn = {
    name = item.name,
    user = os.getenv("DB_USER_" .. suffix),
    password = os.getenv("DB_PASSWORD_" .. suffix),
    host = os.getenv("DB_HOST_" .. suffix),
    port = os.getenv("DB_PORT_" .. suffix),
    database = os.getenv("DB_NAME_" .. suffix),
  }

  for _, field in ipairs({
    "user",
    "password",
    "host",
    "port",
    "database",
  }) do
    if not conn[field] or conn[field] == "" then
      return nil
    end
  end

  return conn
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
      return string.format(
        "%s  (%s:%s/%s)",
        item.name,
        item.host,
        item.port,
        item.database
      )
    end,
  }, function(choice)
    if not choice then
      return
    end

    -- 只保存连接名称，不把密码写进 buffer 变量。
    vim.b.sql_connection_name = choice.name

    vim.notify(
      "当前 SQL 连接：" .. choice.name,
      vim.log.levels.INFO
    )
  end)
end

local function current_connection()
  local name = vim.b.sql_connection_name

  if not name then
    return nil
  end

  for _, item in ipairs(connection_defs) do
    if item.name == name then
      return get_connection(item)
    end
  end

  return nil
end

local function show_result(text, connection_name)
  local current_win = vim.api.nvim_get_current_win()

  vim.cmd("botright new")

  local buf = vim.api.nvim_get_current_buf()

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "sql"

  vim.api.nvim_buf_set_name(
    buf,
    "mysql://" .. connection_name .. "/result"
  )

  local lines = vim.split(text or "", "\n", {
    plain = true,
  })

  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end

  if #lines == 0 then
    lines = { "(no output)" }
  end

  vim.api.nvim_buf_set_lines(
    buf,
    0,
    -1,
    false,
    lines
  )

  vim.bo[buf].modifiable = false

  -- 执行后回到原 SQL 文件。
  if vim.api.nvim_win_is_valid(current_win) then
    vim.api.nvim_set_current_win(current_win)
  end
end

function M.run(sql)
  local conn = current_connection()

  if not conn then
    vim.notify(
      "当前 SQL 文件还没有选择数据库，请先按 <leader>sc",
      vim.log.levels.WARN
    )
    return
  end

  if not sql or sql:match("^%s*$") then
    vim.notify("没有可执行的 SQL", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("mysql.exe") ~= 1 then
    vim.notify(
      "找不到 mysql.exe，请检查 PATH",
      vim.log.levels.ERROR
    )
    return
  end

  vim.system({
    "mysql.exe",
    "--host=" .. conn.host,
    "--port=" .. conn.port,
    "--user=" .. conn.user,
    "--database=" .. conn.database,
    "--default-character-set=utf8mb4",
    "--table",
    "--raw",
  }, {
    stdin = sql,
    text = true,

    -- 不把密码放进命令行参数。
    env = vim.tbl_extend("force", vim.fn.environ(), {
      MYSQL_PWD = conn.password,
    }),
  }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        show_result(
          obj.stderr ~= "" and obj.stderr or obj.stdout,
          conn.name
        )
        return
      end

      show_result(obj.stdout, conn.name)
    end)
  end)
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
