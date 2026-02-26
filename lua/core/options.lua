local opt = vim.opt
opt.number = true          -- 显示行号
opt.relativenumber = false -- 不显示相对行号
opt.cursorline = false     -- 当前行不加下划线
opt.wrap = false           -- 不自动换行
opt.showcmd = true         -- 显示执行的命令
opt.wildmenu = true        -- 命令补全菜单
opt.hlsearch = true        -- 搜索结果高亮
vim.cmd("nohlsearch")      -- 启动时清除高亮
opt.incsearch = true       -- 搜索时高亮
opt.ignorecase = true      -- 搜索忽略大小写
opt.smartcase = true       -- 搜索时大小写混输则精确匹配大小写
opt.mouse = 'a'            -- 允许使用鼠标
opt.encoding = 'utf-8'
opt.expandtab = true       -- 将tab键改为输入空格
opt.tabstop = 2            -- 设置tab键的缩进距离
opt.shiftwidth = 2         -- 设置代码位移和自动缩进时的长度
opt.softtabstop = 2        -- 设置缩进长度
opt.list = true            -- 显示行尾的空格
opt.listchars = { tab = '▸ ', trail = '·', extends = '❯', precedes = '❮', nbsp = '×' }
opt.textwidth = 0          -- 关闭自动换行
opt.indentexpr = ''        -- 关闭智能缩进表达式
opt.backspace = { 'indent', 'eol', 'start' }
opt.foldmethod = 'indent'  -- 代码折叠
opt.foldlevel = 99         -- 默认显示折叠层数
opt.laststatus = 2         -- 始终在窗口底部显示文件信息
opt.autochdir = true       -- 自动将工作目录切换到当前文件所在的目录
opt.updatetime = 300       -- 设置刷新时间为300毫秒
opt.signcolumn = 'auto'    -- 在左侧显示标记列（报错图标等）
opt.scrolloff = 10         -- 底部永远空10行
opt.conceallevel = 3       -- neovim 隐藏级别


-- 遵循PEP 8 规范，python使用4格空格缩进
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    -- 注意这里使用的是 opt_local，这意味着它只对当前 Python 缓冲区生效，不会污染全局的 2 空格设置
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true
  end,
})


vim.cmd([[
  " 开启底层高亮组件
  syntax on
  " 核心逻辑：记录并恢复上次退出文件时的光标位置
  augroup restore_cursor
    autocmd!
    autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
  augroup END
]])
