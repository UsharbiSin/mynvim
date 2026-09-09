-- Windows WezTerm 兼容层：用 image.nvim 普通 Kitty 定位显示图片、公式和图表。
local M = {}
local inline_enabled = true
local math_images = {}
local watch_padding

function M.is_windows()
  return vim.g.is_win == 1 or vim.fn.has('win32') == 1
end

function M.enabled()
  return M.is_windows() and vim.env.WEZTERM_PANE ~= nil
end

function M.active()
  return inline_enabled
end

function M.size_from_panes(panes, pane_id)
  for _, pane in ipairs(panes) do
    local size = pane.size or {}
    if tostring(pane.pane_id) == tostring(pane_id)
        and (size.cols or 0) > 0 and (size.rows or 0) > 0
        and (size.pixel_width or 0) > 0 and (size.pixel_height or 0) > 0 then
      return {
        screen_x = size.pixel_width,
        screen_y = size.pixel_height,
        screen_cols = size.cols,
        screen_rows = size.rows,
        cell_width = size.pixel_width / size.cols,
        cell_height = size.pixel_height / size.rows,
      }
    end
  end
end

function M.setup()
  local terminal_size

  local function update_terminal_size()
    local executable = vim.fn.exepath('wezterm')
    if executable == '' then return end
    vim.system({ executable, 'cli', 'list', '--format', 'json' }, { text = true, timeout = 3000 }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          vim.notify('行内图片：无法读取 WezTerm 尺寸，请检查 wezterm cli list --format json', vim.log.levels.WARN)
          return
        end
        local ok, panes = pcall(vim.json.decode, result.stdout)
        if ok then terminal_size = M.size_from_panes(panes, vim.env.WEZTERM_PANE) end
        if terminal_size then M.refresh() end
      end)
    end)
  end

  -- 替换 image.nvim 的 Unix ioctl/tty 探测，不修改已安装的插件文件。
  local term = {
    get_size = function() return terminal_size end,
    get_tty = function() return nil end,
  }
  package.loaded['image/utils/term'] = term
  package.loaded['image.utils.term'] = term
  package.loaded['image/report'] = {
    create = function(state)
      local lines = {
        '# Windows 行内图片诊断',
        '',
        '后端：' .. tostring(state.options.backend),
        '处理器：' .. tostring(state.options.processor),
        'ImageMagick：' .. vim.fn.exepath('magick'),
        '终端尺寸：' .. vim.inspect(terminal_size),
      }
      local buf = vim.api.nvim_create_buf(false, true)
      vim.cmd('botright split')
      vim.api.nvim_win_set_buf(0, buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].bufhidden = 'wipe'
      vim.bo[buf].modifiable = false
      vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = buf })
      return buf
    end,
  }

  vim.api.nvim_create_autocmd({ 'VimResized', 'FocusGained' }, {
    group = vim.api.nvim_create_augroup('ImageInlineDimensions', { clear = true }),
    callback = update_terminal_size,
  })
  update_terminal_size()

  require('image').setup({
    backend = 'kitty',
    kitty_method = 'normal',
    processor = 'magick_cli',
    integrations = {
      markdown = {
        enabled = true,
        filetypes = { 'markdown', 'vimwiki' },
        clear_in_insert_mode = true,
        only_render_image_at_cursor = false,
        floating_windows = false,
      },
    },
    max_width_window_percentage = 90,
    max_height_window_percentage = 90,
    window_overlap_clear_enabled = true,
    hijack_file_patterns = {},
  })

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'FileType', 'WinResized', 'InsertLeave' }, {
    group = vim.api.nvim_create_augroup('ImageInlineInitialRender', { clear = true }),
    callback = M.refresh,
  })
  M.refresh()
end

local function visible_document(item)
  return item.window
      and vim.api.nvim_win_is_valid(item.window)
      and vim.api.nvim_win_get_buf(item.window) == item.buffer
end

local function align_after_padding(item)
  vim.schedule(function()
    if not visible_document(item) or vim.fn.mode():match('^[iR]') then return end
    vim.cmd('redraw!')
    item.global_state.backend.clear(item.id, true)
    item:render()
  end)
end

watch_padding = function(item)
  if item._wezterm_inline_wrapped then return end
  item._wezterm_inline_wrapped = true
  local original_render = item.render
  item.render = function(self, ...)
    local had_padding = self:get_extmark_id() ~= nil
    local result = original_render(self, ...)
    if not had_padding and self:get_extmark_id() ~= nil then align_after_padding(self) end
    return result
  end
  if item:get_extmark_id() ~= nil then align_after_padding(item) end
end

local function render_math(buf, win)
  if not inline_enabled or not vim.api.nvim_buf_is_valid(buf) then return end
  require('snacks.image.doc').find(buf, function(items)
    local visible = {}
    for _, item in ipairs(items) do
      if item and item.type == 'math' and item.src then
        local key = table.concat({ buf, win, item.id }, ':')
        visible[key] = true
        if math_images[key] == nil then
          local pending = { pending = true }
          math_images[key] = pending
          local conversion = Snacks.image.convert.convert({
            src = item.src,
            on_done = function(result)
              vim.schedule(function()
                -- 文档变化或关闭显示后，旧转换结果不得再次发送到终端。
                if math_images[key] ~= pending then return end
                if not inline_enabled or result:error() or vim.fn.filereadable(result.file) ~= 1 then
                  math_images[key] = nil
                  return
                end
                local image = require('image').from_file(result.file, {
                  buffer = buf,
                  window = win,
                  with_virtual_padding = true,
                  inline = true,
                  x = item.pos[2],
                  y = item.pos[1] - 1,
                  render_offset_top = 1,
                  max_width_window_percentage = 90,
                  max_height_window_percentage = 50,
                })
                if not image then
                  math_images[key] = nil
                  return
                end
                math_images[key] = image
                watch_padding(image)
                image:render()
              end)
            end,
          })
          conversion:run()
        end
      end
    end

    local prefix = '^' .. buf .. ':' .. win .. ':'
    for key, entry in pairs(math_images) do
      if key:match(prefix) and not visible[key] then
        if not entry.pending then entry:clear() end
        math_images[key] = nil
      end
    end
  end)
end

function M.toggle()
  inline_enabled = not inline_enabled
  if M.is_windows() then
    require('lazy').load({ plugins = { 'image.nvim', 'diagram.nvim' } })
    local image = require('image')
    if inline_enabled then
      image.enable()
      M.refresh()
    else
      image.disable()
      for key, entry in pairs(math_images) do
        if not entry.pending then entry:clear() end
        math_images[key] = nil
      end
    end
  else
    Snacks.image.config.enabled = inline_enabled
    if inline_enabled then
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          if vim.b[buf].snacks_image_attached then
            vim.api.nvim_exec_autocmds('BufWinEnter', { buffer = buf, modeline = false })
          else
            Snacks.image.doc.attach(buf)
          end
        end
      end
    else
      require('snacks.image.placement').clean()
    end
  end
  vim.notify('行内显示已' .. (inline_enabled and '开启' or '关闭'))
end

function M.setup_toggle()
  vim.keymap.set('n', '<leader>ilm', M.toggle, { desc = '切换图片、公式和流程图的行内显示' })
end

function M.refresh()
  vim.schedule(function()
    local image = require('image')
    if not inline_enabled or not image.is_enabled() or vim.fn.mode():match('^[iR]') then return end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      if ft == 'markdown' or ft == 'vimwiki' then
        local autocmds = vim.api.nvim_get_autocmds({ group = 'image.nvim:markdown', event = 'BufEnter' })
        if #autocmds > 0 then
          vim.api.nvim_exec_autocmds('BufEnter', {
            group = autocmds[1].group,
            buffer = buf,
            modeline = false,
          })
        end
        render_math(buf, win)
      end
    end

    vim.schedule(function()
      for _, item in ipairs(image.get_images()) do
        if visible_document(item) then watch_padding(item) end
      end
    end)
  end)
end

return M
