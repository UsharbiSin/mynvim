vim.g.table_mode_corner = '|'
vim.g.table_mode_separator = '|'
vim.g.table_mode_fillchar = '-'
vim.g.table_mode_align_char = ':'

local M = {}

local function split_table_row(line)
  local separators = {}
  local escaped = false
  for index = 1, #line do
    local char = line:sub(index, index)
    if char == "|" and not escaped then
      separators[#separators + 1] = index
    end
    if char == "\\" then
      escaped = not escaped
    else
      escaped = false
    end
  end

  if #separators < 2
    or not line:sub(1, separators[1] - 1):match("^%s*$")
    or not line:sub(separators[#separators] + 1):match("^%s*$")
  then
    return nil
  end

  local cells = {}
  for index = 1, #separators - 1 do
    local left = separators[index]
    local right = separators[index + 1]
    cells[#cells + 1] = {
      value = vim.trim(line:sub(left + 1, right - 1)),
      left = left,
      right = right,
    }
  end
  return cells
end

local function is_separator_row(cells)
  local has_marker = false
  for _, cell in ipairs(cells) do
    if cell.value ~= "" and not cell.value:match("^:?-+:?$") then
      return false
    end
    has_marker = has_marker or cell.value ~= ""
  end
  return has_marker
end

local function normalize_table_row(line, cells, column_count)
  local separator = is_separator_row(cells)
  local result = line
  for index = #cells, 1, -1 do
    local cell = cells[index]
    if cell.value == "" then
      local value = separator and "---" or " <++> "
      result = result:sub(1, cell.left) .. value .. result:sub(cell.right)
    end
  end

  if #cells < column_count then
    result = result:gsub("|%s*$", "")
    local cell = separator and "|---" or "| <++> "
    result = result .. cell:rep(column_count - #cells) .. "|"
  end
  return result
end

function M.sync_columns(bufnr, lnum)
  local current = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
  if not current or not split_table_row(current) then
    return nil
  end

  local first = lnum
  while first > 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, first - 2, first - 1, false)[1]
    if not line or not split_table_row(line) then
      break
    end
    first = first - 1
  end

  local last = lnum
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  while last < line_count do
    local line = vim.api.nvim_buf_get_lines(bufnr, last, last + 1, false)[1]
    if not line or not split_table_row(line) then
      break
    end
    last = last + 1
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, first - 1, last, false)
  local column_count = 0
  local separator_lnum
  for index, line in ipairs(lines) do
    local cells = split_table_row(line)
    column_count = math.max(column_count, #cells)
    if is_separator_row(cells) then
      separator_lnum = first + index - 1
    end
  end

  local changed = false
  for index, line in ipairs(lines) do
    local cells = split_table_row(line)
    local normalized = normalize_table_row(line, cells, column_count)
    if normalized ~= line then
      lines[index] = normalized
      changed = true
    end
  end
  if changed then
    vim.api.nvim_buf_set_lines(bufnr, first - 1, last, false, lines)
  end
  return column_count, separator_lnum
end

function M.sync_current()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local at_end = cursor[2] >= math.max(#line - 1, 0)
  M.sync_columns(bufnr, cursor[1])
  if at_end then
    local normalized = vim.api.nvim_get_current_line()
    vim.api.nvim_win_set_cursor(0, { cursor[1], #normalized })
  end
end

function M.insert_row(bufnr, lnum)
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
  local cells = line and split_table_row(line)
  if not cells or #cells == 0 then
    return false
  end

  local column_count, separator_lnum = M.sync_columns(bufnr, lnum)
  local insert_after = lnum
  local new_lines
  if not separator_lnum then
    new_lines = { ("|---"):rep(column_count) .. "|", ("| <++> "):rep(column_count) .. "|" }
  else
    if lnum < separator_lnum then
      insert_after = separator_lnum
    end
    new_lines = { ("| <++> "):rep(column_count) .. "|" }
  end

  vim.api.nvim_buf_set_lines(bufnr, insert_after, insert_after, false, new_lines)
  vim.api.nvim_win_set_cursor(0, { insert_after + #new_lines, 2 })
  return true
end

return M
