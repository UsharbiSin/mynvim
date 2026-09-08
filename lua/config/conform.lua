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
})
