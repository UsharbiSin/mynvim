vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("SetupDebugging", { clear = true }),
  pattern = { "python", "cpp", "cuda", "c" },
  once = true,
  callback = function()
    require('config.debugging')
  end,
})
