local M = {}

local cache = {}

local function one_line(value)
  return tostring(value or ""):gsub("[\r\n\t]", " ")
end

local metadata_sql = [[
SELECT
  t.TABLE_NAME,
  COALESCE(t.TABLE_COMMENT, ''),
  t.TABLE_TYPE,
  COALESCE(c.COLUMN_NAME, ''),
  COALESCE(c.COLUMN_COMMENT, ''),
  COALESCE(c.COLUMN_TYPE, '')
FROM information_schema.TABLES AS t
LEFT JOIN information_schema.COLUMNS AS c
  ON c.TABLE_SCHEMA = t.TABLE_SCHEMA
 AND c.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_SCHEMA = DATABASE()
ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION
]]

function M.parse(rows)
  local tables = {}
  local by_name = {}

  for _, row in ipairs(rows or {}) do
    local name = one_line(row[1])
    local item = by_name[name]
    if name ~= "" and not item then
      item = {
        name = name,
        comment = one_line(row[2]),
        type = row[3] == "VIEW" and "view" or "table",
        columns = {},
      }
      by_name[name] = item
      table.insert(tables, item)
    end

    if item and row[4] and row[4] ~= "" then
      table.insert(item.columns, {
        name = one_line(row[4]),
        comment = one_line(row[5]),
        type = one_line(row[6]),
      })
    end
  end

  return tables
end

function M.search_text(item)
  local parts = { item.name, item.comment }
  for _, column in ipairs(item.columns or {}) do
    table.insert(parts, column.name)
    table.insert(parts, column.comment)
  end
  return table.concat(parts, " "):lower()
end

function M.filter(tables, query)
  query = vim.trim(query or ""):lower()
  if query == "" then
    return tables
  end

  local result = {}
  for _, item in ipairs(tables or {}) do
    if M.search_text(item):find(query, 1, true) then
      table.insert(result, item)
    end
  end
  return result
end

function M.fetch(url, force)
  if not force and cache[url] then
    return cache[url]
  end

  local result, err
  require("dadbod-grip.ui").blocking("  正在读取数据库注释...", function()
    result, err = require("dadbod-grip.db").query(metadata_sql, url)
  end)
  if not result then
    return nil, err or "读取数据库注释失败"
  end

  local tables = M.parse(result.rows)
  cache[url] = tables
  return tables
end

function M.clear(url)
  cache[url] = nil
end

function M.column_comments(tables, columns, table_name)
  local wanted = {}
  for _, column in ipairs(columns or {}) do
    wanted[column] = true
  end

  local result = {}
  for _, item in ipairs(tables or {}) do
    local bare_name = item.name:match("([^.]+)$")
    local bare_target = table_name and table_name:match("([^.]+)$")
    if not table_name or item.name == table_name or bare_name == bare_target then
      for _, column in ipairs(item.columns or {}) do
        if wanted[column.name] and column.comment ~= "" then
          table.insert(result, {
            table_name = item.name,
            column_name = column.name,
            type = column.type,
            comment = column.comment,
          })
        end
      end
    end
  end
  return result
end

return M
