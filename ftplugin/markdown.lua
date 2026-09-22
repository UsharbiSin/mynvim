local map = vim.keymap.set
local table_mode = require('config.vim-table-mode')
-- 只在 Markdown 中生效
local opts = { buffer = true, silent = true }

local function visual_end_col(line, one_based_col)
  local col = math.max(one_based_col - 1, 0)
  if col >= #line then
    return #line
  end

  local char_index = vim.fn.charidx(line, col)
  local next_col = vim.fn.byteidx(line, char_index + 1)
  return next_col >= 0 and next_col or #line
end

local function wrap_visual(prefix, suffix)
  local mode = vim.fn.mode()
  local region = vim.fn.getregionpos(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = mode })
  if #region == 0 then
    return
  end

  -- 块选择不是连续文本，逐行包裹，避免把矩形范围之外的字符一起改掉。
  if mode == '\22' then
    for index = #region, 1, -1 do
      local segment = region[index]
      local start_pos = segment[1]
      local end_pos = segment[2]
      local row = start_pos[2] - 1
      local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ''
      local start_col = math.max(start_pos[3] - 1, 0)
      local end_col = visual_end_col(line, end_pos[3])
      local selected = vim.api.nvim_buf_get_text(0, row, start_col, row, end_col, {})[1] or ''
      vim.api.nvim_buf_set_text(0, row, start_col, row, end_col, { prefix .. selected .. suffix })
    end
  else
    local start_pos = region[1][1]
    local end_pos = region[#region][2]
    local start_row = start_pos[2] - 1
    local end_row = end_pos[2] - 1
    local start_col = math.max(start_pos[3] - 1, 0)
    local end_line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1] or ''
    local end_col = visual_end_col(end_line, end_pos[3])
    local selected = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})

    selected[1] = prefix .. (selected[1] or '')
    selected[#selected] = (selected[#selected] or '') .. suffix
    vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, selected)
  end

  vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'nx', false)
end

-- 插入模式下的标记补全
map('i', ',f', function()
  local position = vim.fn.searchpos([[\V<++>]], '')
  if position[1] == 0 then
    return
  end

  local row = position[1] - 1
  local column = position[2] - 1
  vim.api.nvim_buf_set_text(0, row, column, row, column + 4, { '' })
  vim.api.nvim_win_set_cursor(0, { position[1], column })
  vim.cmd('nohlsearch')
end, vim.tbl_extend('force', opts, { desc = "替换下一个 Markdown 占位符" }))
map('i', ',n', '---<Enter><Enter>', opts)
map('i', ',b', '**** <++><Esc>F*hi', opts)
map('i', ',s', '~~~~ <++><Esc>F~hi', opts)
map('i', ',i', '** <++><Esc>F*i', opts)
map('i', ',d', '`` <++><Esc>F`i', opts)
map('i', ',c', '``` <Enter><++><Enter>```<Enter><Enter><++><Esc>4kA', opts)
map('i', ',h', '<mark></mark> <++><Esc>F/hi', opts)
map('i', ',p', '![](<++>) <++><Esc>F[a', opts)
map('i', ',a', '[](<++>) <++><Esc>F[a', opts)
map('i', ',1', '# <Enter><++><Esc>kA', opts)
map('i', ',2', '## <Enter><++><Esc>kA', opts)
map('i', ',3', '### <Enter><++><Esc>kA', opts)
map('i', ',4', '#### <Enter><++><Esc>kA', opts)
map('i', ',l', '--------<Enter>', opts)
map('i', '.rd', '<a style="color: red;"></a> <++><Esc>F/hi', opts)
map('i', '.bl', '<a style="color: blue;"></a> <++><Esc>F/hi', opts)
map('i', '.yl', '<a style="color: yellow;"></a> <++><Esc>F/hi', opts)
map('i', '.br', '<a style="color: brown;"></a> <++><Esc>F/hi', opts)
map('i', '.gr', '<a style="color: green;"></a> <++><Esc>F/hi', opts)

-- 可视模式：直接包裹当前选区
map('x', ',b', function() wrap_visual('**', '**') end,
  vim.tbl_extend('force', opts, { desc = 'Markdown 选区加粗' }))
map('x', ',i', function() wrap_visual('*', '*') end,
  vim.tbl_extend('force', opts, { desc = 'Markdown 选区斜体' }))
map('x', '.rd', function() wrap_visual('<a style="color: red;">', '</a>') end,
  vim.tbl_extend('force', opts, { desc = 'Markdown 选区设为红色' }))
map('x', '.bl', function() wrap_visual('<a style="color: blue;">', '</a>') end,
  vim.tbl_extend('force', opts, { desc = 'Markdown 选区设为蓝色' }))
map('x', '.yl', function() wrap_visual('<a style="color: yellow;">', '</a>') end,
  vim.tbl_extend('force', opts, { desc = 'Markdown 选区设为黄色' }))
map('x', '.br', function() wrap_visual('<a style="color: brown;">', '</a>') end,
  vim.tbl_extend('force', opts, { desc = 'Markdown 选区设为棕色' }))
map('x', '.gr', function() wrap_visual('<a style="color: green;">', '</a>') end,
  vim.tbl_extend('force', opts, { desc = 'Markdown 选区设为绿色' }))


-- 拦截回车键：在表格行尾回车时，自动填充 <++> 占位符
local saved_cr_maps = {} -- 按 buffer 独立保存原有的回车映射

-- 当 Table Mode 开启时：动态挂载拦截器
vim.api.nvim_create_autocmd("User", {
  pattern = "TableModeEnabled",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    -- 备份当前 buffer 原有的 <CR> 映射（比如 bullets.vim 的）
    saved_cr_maps[bufnr] = vim.fn.maparg('<CR>', 'i', false, true)

    -- <Cmd> 在插入模式内执行同步，不会触发 im-select 的 InsertLeave。
    vim.keymap.set('i', '|', "|<Cmd>lua require('config.vim-table-mode').sync_current()<CR>", {
      buffer = bufnr,
      silent = true,
      desc = "插入表格分隔符并同步列数",
    })

    -- 注入表格专用的 <CR> 拦截器。
    vim.keymap.set('i', '<CR>', function()
      local lnum = vim.fn.line('.')
      local saved_map = saved_cr_maps[bufnr]

      -- 如果在表格内回车
      if table_mode.insert_row(bufnr, lnum) then
        return
      end

      -- 如果光标不在表格内，完全放行给被备份的插件逻辑
      if saved_map and saved_map.rhs and saved_map.rhs ~= "" then
        local mode = saved_map.noremap == 1 and 'n' or 'm'
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(saved_map.rhs, true, false, true), mode, false)
      elseif saved_map and saved_map.callback then
        saved_map.callback()
      else
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), 'n', false)
      end
    end, { buffer = bufnr, silent = true, desc = "表格回车自动生成(仅在开启时拦截)" })
  end
})

-- 当 Table Mode 关闭时：卸载拦截器
vim.api.nvim_create_autocmd("User", {
  pattern = "TableModeDisabled",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local saved_map = saved_cr_maps[bufnr]

    if saved_map and not vim.tbl_isempty(saved_map) then
      -- 原汁原味恢复之前的插件映射
      if saved_map.rhs and saved_map.rhs ~= "" then
        vim.keymap.set('i', '<CR>', saved_map.rhs, {
          buffer = bufnr,
          expr = saved_map.expr == 1,
          noremap = saved_map.noremap == 1,
          silent = saved_map.silent == 1,
          nowait = saved_map.nowait == 1,
        })
      elseif saved_map.callback then
        vim.keymap.set('i', '<CR>', saved_map.callback, {
          buffer = bufnr,
          expr = saved_map.expr == 1,
          noremap = saved_map.noremap == 1,
          silent = saved_map.silent == 1,
          nowait = saved_map.nowait == 1,
        })
      end
    else
      -- 如果原来没映射，直接删掉咱们加的拦截器
      pcall(vim.keymap.del, 'i', '<CR>', { buffer = bufnr })
    end

    -- 清理内存
    saved_cr_maps[bufnr] = nil
  end
})
