vim.g.table_mode_corner = '|'
vim.g.table_mode_separator = '|'
vim.g.table_mode_fillchar = '-'
vim.g.table_mode_align_char = ':'

local M = {}

local function split_table_row(line)
  local body = line:match("^%s*|(.*)|%s*$")
  if not body then
    return nil
  end

  local cells = {}
  local start = 1
  local escaped = false
  for index = 1, #body do
    local char = body:sub(index, index)
    if char == "|" and not escaped then
      cells[#cells + 1] = vim.trim(body:sub(start, index - 1))
      start = index + 1
    end
    if char == "\\" then
      escaped = not escaped
    else
      escaped = false
    end
  end
  cells[#cells + 1] = vim.trim(body:sub(start))
  return cells
end

local function is_separator_row(cells)
  for _, cell in ipairs(cells) do
    if not cell:match("^:?-+:?$") then
      return false
    end
  end
  return #cells > 0
end

local function pad_table_row(line, cells, column_count)
  if #cells >= column_count then
    return line
  end

  local result = line:gsub("|%s*$", "")
  local cell = is_separator_row(cells) and "|---" or "| <++> "
  return result .. cell:rep(column_count - #cells) .. "|"
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
    local padded = pad_table_row(line, cells, column_count)
    if padded ~= line then
      lines[index] = padded
      changed = true
    end
  end
  if changed then
    vim.api.nvim_buf_set_lines(bufnr, first - 1, last, false, lines)
  end
  return column_count, separator_lnum
end

function M.sync_current()
  M.sync_columns(vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1])
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
