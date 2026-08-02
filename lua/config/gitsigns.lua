require('gitsigns').setup({
  current_line_blame = true,
  -- word_diff = true,

  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns
    local function map(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    map('n', '<LEADER>ph', gs.preview_hunk, { desc = "预览当前块的差异" })
    map('n', '<LEADER>td', gs.toggle_deleted, { desc = "开关显示已删除行" })
    map('n', '<LEADER>rh', gs.reset_hunk, { desc = "回滚当前行" })
    map('n', '<LEADER>[h', gs.prev_hunk, { desc = "跳转到上一个修改块" })
    map('n', '<LEADER>]h', gs.next_hunk, { desc = "跳转到下一个修改块" })
  end
})
