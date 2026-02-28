-- 对应原 coc.preferences.formatOnSave
local conform = require("conform")

conform.setup({
  formatters_by_ft = {
    python = { "isort", "black" },

    -- 数据库查询排版
    sql = { "sqlfluff" },

    -- 前端与通用数据格式 (JSON, Markdown等)
    javascript = { "prettier" },
    html = { "prettier" },
    css = { "prettier" },
    json = { "prettier" },
    markdown = { "prettier" },

    -- Neovim 自身的 Lua 配置文件格式化
    lua = { "stylua" },
  },
  format_on_save = {
    timeout_ms = 3000,
    lsp_fallback = false,
  },
})

-- 在不保存文件的情况下触发局部格式化
vim.keymap.set({ "n", "v" }, "<leader>fm", function()
  conform.format({
    lsp_fallback = true,
    async = false,
    timeout_ms = 300,
  })
end, { desc = "手动格式化当前文件或选中代码块" })
