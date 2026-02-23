local map = vim.keymap.set
-- 只在 Markdown 中生效
local opts = { buffer = true, silent = true }

-- 插入模式下的标记补全
map('i', ',f', '<Esc>/<++><CR>:nohlsearch<CR>c4l', opts)
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
map('i', ',r', '<a style="color: red;"></a> <++><Esc>F/hi', opts)
map('i', ',t', '<a style="color: blue;"></a> <++><Esc>F/hi', opts)


-- 拦截回车键：在表格行尾回车时，自动填充 <++> 占位符
local saved_cr_maps = {} -- 按 buffer 独立保存原有的回车映射

-- 当 Table Mode 开启时：动态挂载拦截器
vim.api.nvim_create_autocmd("User", {
  pattern = "TableModeEnabled",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    -- 备份当前 buffer 原有的 <CR> 映射（比如 bullets.vim 的）
    saved_cr_maps[bufnr] = vim.fn.maparg('<CR>', 'i', false, true)

    -- 注入表格专用的 <CR> 拦截器 (注意：去掉了 expr=true，采用原生 feedkeys)
    vim.keymap.set('i', '<CR>', function()
      local line = vim.api.nvim_get_current_line()
      local lnum = vim.fn.line('.')
      local saved_map = saved_cr_maps[bufnr]

      -- 如果在表格内回车
      if line:match("^%s*|.*|%s*$") then
        local pipe_count = 0
        for _ in string.gmatch(line, "|") do pipe_count = pipe_count + 1 end

        if pipe_count >= 2 then
          local cols = pipe_count - 1
          local prev_line = lnum > 1 and vim.fn.getline(lnum - 1) or ""
          local result_keys = ""

          if not prev_line:match("^%s*|.*|%s*$") then
            local sep_row = ""
            local data_row = ""
            for i = 1, cols do
              sep_row = sep_row .. "|---"
              data_row = data_row .. "| <++> "
            end
            sep_row = sep_row .. "|"
            data_row = data_row .. "|"
            result_keys = "<Esc>A<CR>" .. sep_row .. "<CR>" .. data_row
          else
            local data_row = ""
            for i = 1, cols do
              data_row = data_row .. "| <++> "
            end
            data_row = data_row .. "|"
            result_keys = "<Esc>A<CR>" .. data_row
          end

          -- 发送按键生成表格，并阻断其他插件
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(result_keys, true, false, true), 'n', false)
          return
        end
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
