local parsers = { "python", "lua", "c", "cpp", "vim", "vimdoc", "query", "markdown", "markdown_inline", "latex", "css",
  "html", "javascript", "sql" }
require('nvim-treesitter').install(parsers)

-- 启用代码高亮 (替代老版本的 highlight = { enable = true })
-- 新版强制要求用 Neovim 原生 API (vim.treesitter.start) 配合自动命令来启动
vim.api.nvim_create_autocmd('FileType', {
  -- '*' 表示对所有打开的文件都尝试启动高亮
  pattern = '*',
  callback = function(args)
    -- pcall 这里的作用是：如果遇到没装 parser 的冷门文件，安静地跳过，绝不报错弹窗
    pcall(vim.treesitter.start, args.buf)
  end,
})

-- 启用代码折叠 (替代老版本的额外模块)
vim.api.nvim_create_autocmd('FileType', {
  pattern = '*',
  callback = function()
    -- 使用 treesitter 原生的折叠表达式
    vim.opt_local.foldmethod = 'expr'
    vim.opt_local.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  end,
})

-- 用markdown 解析器来解析 vimmarkdown 文件
vim.treesitter.language.register('markdown', 'vimwiki')
