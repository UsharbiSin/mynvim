local parsers = {
  "python", "lua", "c", "cpp", "java", "vim", "vimdoc", "query", "markdown", "markdown_inline",
  "latex", "css", "html", "javascript", "json", "sql",
}
if vim.g.is_win == 1 then
  local gcc = vim.fn.exepath("gcc")
  if gcc ~= "" then vim.env.CC = gcc end
end
require('nvim-treesitter').install(parsers)
local folding = require('config.folding')
folding.setup()

-- 启用代码高亮 (替代老版本的 highlight = { enable = true })
-- 新版强制要求用 Neovim 原生 API (vim.treesitter.start) 配合自动命令来启动
vim.api.nvim_create_autocmd('FileType', {
  -- '*' 表示对所有打开的文件都尝试启动高亮
  pattern = '*',
  callback = function(args)
    -- pcall 这里的作用是：如果遇到没装 parser 的冷门文件，安静地跳过，绝不报错弹窗
    if pcall(vim.treesitter.start, args.buf) then
      vim.schedule(function()
        folding.refresh(args.buf)
      end)
    end
  end,
})

-- 用markdown 解析器来解析 vimmarkdown 文件
vim.treesitter.language.register('markdown', 'vimwiki')
vim.treesitter.language.register('json', 'jsonc')
