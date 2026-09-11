local connections = {}

for _, item in ipairs({
  { "tongyan", "TY" },
  { "tongyan_test", "TYTEST" },
  { "platform_st", "ST" },
  { "platform_st_test", "STTEST" },
}) do
  local name, suffix = item[1], item[2]
  local complete = true
  for _, field in ipairs({ "USER", "PASSWORD", "HOST", "PORT", "NAME" }) do
    local value = os.getenv("DB_" .. field .. "_" .. suffix)
    if not value or value == "" then
      complete = false
      break
    end
  end

  if complete then
    table.insert(connections, {
      name = name,
      url = string.format(
        "mysql://${DB_USER_%s}:${DB_PASSWORD_%s}@${DB_HOST_%s}:${DB_PORT_%s}/${DB_NAME_%s}",
        suffix,
        suffix,
        suffix,
        suffix,
        suffix
      ),
    })
  end
end

-- Grip 可读取 vim-dadbod-ui 格式的内存连接，并在执行命令时才展开环境变量。
vim.g.dbs = connections

require("dadbod-grip").setup({
  ai = false,
  completion = false,
  discovery = false,
  timeout = 300000,
})

require("config.sql-browser").setup()
