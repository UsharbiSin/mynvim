local map = vim.keymap.set

-- 基础配置
map({ 'n', 'v' }, 's', '<Nop>')
map({ 'n', 'v' }, '<Space>', '<Nop>')
map({ 'n', 'v' }, 'R', ':source $MYVIMRC | AirlineRefresh<CR>')
map({ 'n', 'v' }, '<C-s>', ':w<CR>')
map({ 'n', 'v' }, '<C-q>', ':q<CR>')

-- 光标移动优化
-- map({ 'n', 'v' }, 'j', 'jzz', { noremap = true })
-- map({ 'n', 'v' }, 'k', 'kzz', { noremap = true })
map({ 'n', 'v' }, '<C-j>', '5jzz', { noremap = true })
map({ 'n', 'v' }, '<C-k>', '5kzz', { noremap = true })
map({ 'n', 'v' }, 'G', 'Gzz', { noremap = true })
map({ 'n', 'v' }, 'n', 'nzz', { noremap = true })
map({ 'n', 'v' }, 'N', 'Nzz', { noremap = true })

-- 分屏窗口
map('n', 'spl', ':set nosplitright<CR>:vsplit<CR>')
map('n', 'spr', ':set splitright<CR>:vsplit<CR>')
map('n', 'spu', ':set nosplitbelow<CR>:split<CR>')
map('n', 'spb', ':set splitbelow<CR>:split<CR>')

-- 分屏窗口大小调节快捷键
map('n', '<up>', ':res +5<CR>')
map('n', '<down>', ':res -5<CR>')
map('n', '<left>', ':vertical resize -5<CR>')
map('n', '<right>', ':vertical resize +5<CR>')

-- 切换光标在哪个分屏窗口
map('n', '<LEADER>h', '<C-w>h')
map('n', '<LEADER>j', '<C-w>j')
map('n', '<LEADER>k', '<C-w>k')
map('n', '<LEADER>l', '<C-w>l')

-- 标签页管理
map('n', 'tn', ':tabe<CR>')
map('n', 'tl', ':-tabnext<CR>')
map('n', 'tr', ':+tabnext<CR>')

-- 按两下空格找到下一个 '<++>' 竝删除进入插入模式
map('n', '<LEADER><LEADER>', '<Esc>/<++><CR>:nohlsearch<CR>c4l')

-- 视觉模式下单行或多行移动
map('v', '<C-j>', ":m '>+1<CR>gv=gv")
map('v', '<C-k>', ":m '<-2<CR>gv=gv")

-- 取消搜索的高亮
map('n', '<LEADER>nh', ':nohl<CR>')

-- 快速打开 init.lua
map('n', '<LEADER>rc', ':e ~/.config/nvim/init.lua<CR>')

-- 开关拼写检查
map('n', '<LEADER>sc', ':set spell!')

-- figlet大字报
map('n', 'tx', ':r !figlet ')

-- 按下 <LEADER>g 在右侧垂直分屏打开 Gemini CLI
map('n', '<LEADER>g', ':botright vertical terminal gemini<CR>')

-- 从 terminal 模式转为 normal 模式
map('t', '<C-t>', '<C-\\><C-n>', { noremap = true, silent = true })

-- 开启 vim-table-mode
map('n', '<LEADER>tm', ':TableModeToggle<CR>', opts)
