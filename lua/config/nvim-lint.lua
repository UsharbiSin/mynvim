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
  "--exclude-rules=CP02,RF05,ST06",
  "-"
}
sqlfluff.env = vim.fn.environ()
sqlfluff.env.PYTHONUTF8 = "1"
sqlfluff.env.PYTHONIOENCODING = "utf-8"

-- AM04 会把整条查询作为诊断范围返回，导致无关的 FROM、WHERE 等内容也被画黄线。
-- 保留该检查，但将提示精确放到 SELECT 列表中的通配符上。
local sqlfluff_parser = sqlfluff.parser
sqlfluff.parser = function(output, bufnr)
  local diagnostics = sqlfluff_parser(output, bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return diagnostics end

  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.code == "AM04"
        and diagnostic.end_lnum
        and diagnostic.end_lnum > diagnostic.lnum then
      local lines = vim.api.nvim_buf_get_lines(
        bufnr,
        diagnostic.lnum,
        diagnostic.end_lnum + 1,
        false
      )
      for offset, line in ipairs(lines) do
        local wildcard = line:find("*", 1, true)
        if wildcard then
          diagnostic.lnum = diagnostic.lnum + offset - 1
          diagnostic.col = wildcard - 1
          diagnostic.end_lnum = diagnostic.lnum
          diagnostic.end_col = diagnostic.col + 1
          break
        end
      end
    end
  end
  return diagnostics
end

-- 设置自动触发语法检查的时机
local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
  group = lint_augroup,
  callback = function()
    -- 异步调用 sqlfluff，并将结果转化为编辑器的红色/黄色波浪线诊断
    lint.try_lint()
  end,
})
