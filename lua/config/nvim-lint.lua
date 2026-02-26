local lint = require("lint")

-- 将 SQL 文件类型关联到 sqlfluff
lint.linters_by_ft = {
  sql = { "sqlfluff" },
  mysql = { "sqlfluff" },
}

-- 全局指定 MySQL 方言
local sqlfluff = lint.linters.sqlfluff
sqlfluff.args = {
  "lint",
  "--format=json",
  "--dialect=mysql",
  "-"
}

-- 设置自动触发语法检查的时机
local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
  group = lint_augroup,
  callback = function()
    -- 异步调用 sqlfluff，并将结果转化为编辑器的红色/黄色波浪线诊断
    lint.try_lint()
  end,
})
