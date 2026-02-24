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

    map('n', '<LEADER>hp', gs.preview_hunk, { desc = "预览当前块的差异" })
    map('n', '<LEADER>td', gs.toggle_deleted, { desc = "开关显示已删除行" })
  end
})
