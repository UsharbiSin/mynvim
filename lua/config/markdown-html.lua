local M = {}

local namespace = vim.api.nvim_create_namespace("markdown_inline_html")
local supported_tags = { a = true, span = true }
local color_groups = {}

local function normalize_color(value)
  value = vim.trim(value):lower()
  local short = value:match("^#(%x%x%x)$")
  if short then
    return "#" .. short:gsub(".", "%0%0")
  end
  if value:match("^#%x%x%x%x%x%x$") then
    return value
  end

  local red, green, blue = value:match("^rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)$")
  if red then
    red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
    if red <= 255 and green <= 255 and blue <= 255 then
      return string.format("#%02x%02x%02x", red, green, blue)
    end
    return nil
  end

  local number = vim.api.nvim_get_color_by_name(value)
  if number >= 0 then
    return string.format("#%06x", number)
  end
end

local function style_color(attributes)
  local lower = attributes:lower()
  local _, style_start, quote = lower:find("style%s*=%s*(['\"])")
  if not style_start then
    return nil
  end
  local style_end = lower:find(quote, style_start + 1, true)
  if not style_end then
    return nil
  end
  local style = attributes:sub(style_start + 1, style_end - 1)
  local value = style:lower():match("color%s*:%s*([^;]+)")
  return value and normalize_color(value) or nil
end

local function parse_line(line)
  local result = {}
  local offset = 1
  while offset <= #line do
    local open_start, open_end, tag, attributes = line:find("<([%a]+)(.-)>", offset)
    if not open_start then
      break
    end
    tag = tag:lower()
    local color = supported_tags[tag] and style_color(attributes) or nil
    if color then
      local close_start, close_end = line:find("</" .. tag .. "%s*>", open_end + 1)
      if close_start then
        result[#result + 1] = {
          color = color,
          open_start = open_start - 1,
          open_end = open_end,
          text_start = open_end,
          text_end = close_start - 1,
          close_start = close_start - 1,
          close_end = close_end,
        }
        offset = close_end + 1
      else
        offset = open_end + 1
      end
    else
      offset = open_end + 1
    end
  end
  return result
end

local function highlight_group(color)
  local group = color_groups[color]
  if group then
    return group
  end
  group = "MarkdownHtmlColor" .. color:sub(2):upper()
  vim.api.nvim_set_hl(0, group, { fg = color })
  color_groups[color] = group
  return group
end

local function render(buffer, first_row, last_row)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end
  local filetype = vim.bo[buffer].filetype
  if filetype ~= "markdown" and filetype ~= "vimwiki" then
    return
  end

  first_row = first_row or 0
  last_row = last_row or vim.api.nvim_buf_line_count(buffer)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, first_row, last_row)
  local inserting = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
  for index, line in ipairs(vim.api.nvim_buf_get_lines(buffer, first_row, last_row, false)) do
    local row = first_row + index - 1
    for _, item in ipairs(parse_line(line)) do
      local group = highlight_group(item.color)
      if item.text_end > item.text_start then
        vim.api.nvim_buf_set_extmark(buffer, namespace, row, item.text_start, {
          end_col = item.text_end,
          hl_group = group,
          priority = 150,
        })
      end
      if not inserting then
        vim.api.nvim_buf_set_extmark(buffer, namespace, row, item.open_start, {
          end_col = item.open_end,
          conceal = "",
        })
        vim.api.nvim_buf_set_extmark(buffer, namespace, row, item.close_start, {
          end_col = item.close_end,
          conceal = "",
        })
      end
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("markdown_inline_html", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "InsertEnter", "InsertLeave" }, {
    group = group,
    pattern = { "*.md", "*.markdown" },
    callback = function(args)
      vim.schedule(function()
        if args.event == "TextChanged" or args.event == "TextChangedI" then
          local row = vim.api.nvim_win_get_cursor(0)[1] - 1
          local last_row = vim.api.nvim_buf_line_count(args.buf)
          render(args.buf, math.max(0, row - 1), math.min(last_row, row + 2))
        else
          render(args.buf)
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "markdown", "vimwiki" },
    callback = function(args)
      vim.schedule(function()
        render(args.buf)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      color_groups = {}
      render(vim.api.nvim_get_current_buf())
    end,
  })

  render(vim.api.nvim_get_current_buf())
end

M.parse_line = parse_line

return M
