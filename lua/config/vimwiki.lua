-- 配置 vimwiki 路径及语法解析格式
vim.g.vimwiki_list = {
  {
    path = '~/vimwiki/',
    syntax = 'markdown',
    ext = '.md'
  }
}

vim.g.vimwiki_table_auto_fmt = 0
vim.g.vimwiki_key_mappings = {
  all_maps = 1,
  global = 1,
  table_format = 0,
  table_mappings = 0,
}
