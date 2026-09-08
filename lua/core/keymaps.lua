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
map('n', '<LEADER>rc', ':e ' .. vim.fn.stdpath('config') .. '/init.lua<CR>')

-- 开关拼写检查
map('n', '<LEADER>sc', ':set spell!')

-- figlet大字报
map('n', 'tx', ':r !figlet ')

-- 按下 <LEADER>g 在右侧垂直分屏打开 Gemini CLI
map('n', '<LEADER>g', ':botright vertical terminal gemini<CR>')

-- Codex：按项目复用终端，恢复历史会话；配置由 Snacks 初始化。
map('n', '<LEADER>ac', '<cmd>Codex<CR>', { desc = "开关当前项目的 Codex" })
map('n', '<LEADER>ar', '<cmd>CodexResume<CR>', { desc = "恢复 Codex 历史会话" })

-- 从 terminal 模式转为 normal 模式
map('t', '<C-t>', '<C-\\><C-n>', { noremap = true, silent = true })

-- 开启 vim-table-mode
map('n', '<LEADER>tm', ':TableModeToggle<CR>')

-- SQLS 命令是 buffer-local，只在 SQL 文件中创建对应快捷键。
local sql_keymaps = vim.api.nvim_create_augroup('SqlKeymaps', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = sql_keymaps,
  pattern = { 'sql', 'mysql' },
  callback = function(event)
    local function sql_map(mode, lhs, rhs, desc)
      map(mode, lhs, rhs, { buffer = event.buf, silent = true, desc = desc })
    end

    sql_map('n', '<LEADER>swc', '<cmd>SqlsSwitchConnection<CR>', 'SQL：切换连接')
    sql_map('n', '<LEADER>swd', '<cmd>SqlsSwitchDatabase<CR>', 'SQL：切换数据库')
    sql_map('n', '<LEADER>ssc', '<cmd>SqlsShowConnections<CR>', 'SQL：显示连接列表')
    sql_map('n', '<LEADER>ssd', '<cmd>SqlsShowDatabases<CR>', 'SQL：显示数据库列表')
    sql_map('n', '<LEADER>sst', '<cmd>SqlsShowTables<CR>', 'SQL：显示数据表')
    sql_map('n', '<LEADER>se', '<cmd>SqlsExecuteQuery<CR>', 'SQL：执行整个缓冲区')
    sql_map('x', '<LEADER>se', ":<C-U>'<,'>SqlsExecuteQuery<CR>", 'SQL：执行选中行')
    sql_map('n', '<LEADER>sv', '<cmd>SqlsExecuteQueryVertical<CR>', 'SQL：纵向显示查询结果')
    sql_map('x', '<LEADER>sv', ":<C-U>'<,'>SqlsExecuteQueryVertical<CR>", 'SQL：纵向显示选中行结果')
  end,
})

-- 密码查看
map('n', '<LEADER>pw', ':e $USERPROFILE/Documents/pswd.md<CR>')


-- windows 下，打开 wezterm终端的配置
if vim.g.is_win == 1 then
  map('n', '<LEADER>wezt', ':e $USERPROFILE/.config/wezterm/wezterm.lua<CR>')
end
