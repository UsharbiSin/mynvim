-- 配置 ALE 使用的 linter (代码检查工具)
vim.g.ale_linters = {
  python = { 'pylint' }
}

-- 配置 ALE 使用的 fixer (代码自动格式化工具)
vim.g.ale_fixers = {
  python = { 'autopep8', 'yapf' }
}
