local cmp = require('cmp')
require('lspkind')

cmp.setup({
  -- 对应 suggest.noselect: true 和 suggest.enablePreselect: false
  completion = {
    completeopt = 'menu,menuone,noselect',
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),            -- 补全项文档翻页
    ['<C-f>'] = cmp.mapping.scroll_docs(4),             -- 补全项文档翻页
    ['<C-Space>'] = cmp.mapping.complete(),             -- 手动触发补全
    ['<CR>'] = cmp.mapping.confirm({ select = false }), -- 确认补全项，select=false 对应 noselect
    ['<Tab>'] = cmp.mapping.select_next_item(),         -- 向下选择补全项
    ['<S-Tab>'] = cmp.mapping.select_prev_item(),       -- 向上选择补全项
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'buffer' },
    { name = 'path' },
  }),
})
