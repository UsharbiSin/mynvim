local hooks = require("ibl.hooks")

-- 使用固定前景色，避免主题重载后因背景色差异过小而看似消失。
hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
  vim.api.nvim_set_hl(0, "IndentGuide", { fg = "#3b4261", nocombine = true })
  vim.api.nvim_set_hl(0, "IndentScope", { fg = "#7aa2f7", bold = true, nocombine = true })
end)

require("ibl").setup({
  indent = { char = "│", tab_char = "│", highlight = "IndentGuide" },
  scope = {
    enabled = true,
    char = "│",
    highlight = "IndentScope",
    show_start = false,
    show_end = false,
  },
  exclude = {
    filetypes = { "checkhealth", "help", "lazy", "lspinfo", "man", "NvimTree", "notify", "noice", "qf" },
    buftypes = { "nofile", "nowrite", "prompt", "quickfix", "terminal" },
  },
})
