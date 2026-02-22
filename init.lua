vim.g.mapleader = " "

-- 禁用不需要的外部语言 Provider，保持 :checkhealth 满绿状态
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- nvim-treesitter 语言包
vim.g.treesitter_ensure_installed = { "python", "lua", "c", "cpp", "vim", "vimdoc", "query" }


-- ==========================================
-- 加载核心配置 (Core)
-- ==========================================
require('core.options')
require('core.keymaps')


-- ==========================================
-- 插件管理 (vim-plug)
-- ==========================================
local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.local/share/nvim/plugged')
Plug('vim-airline/vim-airline') -- 美化底部状态栏
-- Plug('connorholyday/vim-snazzy') -- 色彩主题
Plug('folke/tokyonight.nvim')   -- 色彩主题
-- Plug('preservim/nerdtree', { on = 'NERDTreeToggle' })                -- 文件树，仅按需加载
-- Plug('Xuyuanp/nerdtree-git-plugin')                                     -- 文件树 Git 状态显示
-- Plug('neoclide/coc.nvim', { branch = 'release' })                       -- 强大的智能代码补全引擎
-- Plug('dense-analysis/ale')                                              -- 异步代码纠错与格式化
Plug('preservim/tagbar', { on = 'TagbarOpenAutoClose' })                                             -- 侧边栏函数大纲
Plug('mbbill/undotree')                                                                              -- 可视化撤销历史树
Plug('preservim/vim-indent-guides')                                                                  -- 可视化显示缩进级别
Plug('itchyny/vim-cursorword')                                                                       -- 自动高亮当前光标下的单词
Plug('rhysd/conflict-marker.vim')                                                                    -- 辅助解决 Git 合并冲突
Plug('tpope/vim-fugitive')                                                                           -- Git 深度集成工具
Plug('mhinz/vim-signify')                                                                            -- 侧边栏版本差异可视化
Plug('gisphm/vim-gitignore', { ['for'] = { 'gitignore', 'vim-plug' } })                              -- 快速生成 .gitignore
Plug('elzr/vim-json')                                                                                -- JSON 文件解析与优化
Plug('hail2u/vim-css3-syntax')                                                                       -- CSS3 语法高亮优化
Plug('spf13/PIV', { ['for'] = { 'php', 'vim-plug' } })                                               -- PHP 优化
Plug('gko/vim-coloresque', { ['for'] = { 'vim-plug', 'php', 'html', 'javascript', 'css', 'less' } }) -- 颜色代码实时预览
Plug('pangloss/vim-javascript', { ['for'] = { 'javascript', 'vim-plug' } })                          -- JS 优化
Plug('mattn/emmet-vim')                                                                              -- HTML/CSS 代码快速生成
Plug('vim-scripts/indentpython.vim')                                                                 -- Python 自动缩进优化
Plug('iamcco/markdown-preview.nvim',
  { ['do'] = function() vim.fn['mkdp#util#install']() end, ['for'] = { 'markdown', 'vim-plug' } })   -- Markdown 浏览器实时预览
Plug('iamcco/mathjax-support-for-mkdp')                                                              -- Markdown 数学公式支持
Plug('dhruvasagar/vim-table-mode', { on = 'TableModeToggle' })                                       -- 强大的表格自动排版
Plug('vimwiki/vimwiki')                                                                              -- 个人知识库系统
Plug('kshenoy/vim-signature')                                                                        -- 侧边栏书签标记显示
Plug('terryma/vim-multiple-cursors')                                                                 -- 类似 Sublime 的多光标编辑
Plug('junegunn/goyo.vim')                                                                            -- 沉浸式专注写作模式
Plug('tpope/vim-surround')                                                                           -- 快速增删改括号/引号等成对符号
Plug('godlygeek/tabular')                                                                            -- 强大的按符号对齐工具
Plug('gcmt/wildfire.vim')                                                                            -- 回车键智能选中文本对象
Plug('scrooloose/nerdcommenter')                                                                     -- 代码批量注释神器
Plug('MarcWeber/vim-addon-mw-utils')                                                                 -- 插件底层依赖
Plug('kana/vim-textobj-user')                                                                        -- 文本对象底层依赖
Plug('fadein/vim-FIGlet')                                                                            -- 生成 ASCII 艺术大字
Plug('img-paste-devs/img-paste.vim')                                                                 -- Markdown 剪贴板一键贴图
Plug('mfussenegger/nvim-dap')                                                                        -- debug辅助
Plug('nvim-neotest/nvim-nio')                                                                        -- 提供异步I/O功能
Plug('rcarriga/nvim-dap-ui')                                                                         -- 提供debug ui
Plug('nvim-treesitter/nvim-treesitter', { ['do'] = ':TSUpdate' })                                    -- 供nvim-dap-virtual-text查找变量定义
Plug('MunifTanjim/nui.nvim')                                                                         -- UI基础库插件，供noice.vim 依赖
Plug('rcarriga/nvim-notify')                                                                         -- 供noice.nvim 依赖，接管通知
Plug('theHamsta/nvim-dap-virtual-text')                                                              -- 调试时在行内显示变量值
Plug('folke/noice.nvim')                                                                             -- 美化输入框
Plug('mfussenegger/nvim-dap-python')                                                                 -- 桥接python-debugpy
Plug('neovim/nvim-lspconfig')                                                                        -- 原生 LSP 核心配置
Plug('williamboman/mason.nvim')                                                                      -- LSP/Linter/Formatter 安装管理器
Plug('williamboman/mason-lspconfig.nvim')                                                            -- 桥接 mason 和 lspconfig
Plug('hrsh7th/nvim-cmp')                                                                             -- 补全引擎核心
Plug('hrsh7th/cmp-nvim-lsp')                                                                         -- LSP 补全源
Plug('hrsh7th/cmp-buffer')                                                                           -- Buffer 补全源
Plug('hrsh7th/cmp-path')                                                                             -- 路径补全源
Plug('onsails/lspkind.nvim')                                                                         -- 补全菜单图标 (替代 suggest.completionItemKindLabels)
Plug('stevearc/conform.nvim')                                                                        -- 格式化代码工具（替代 coc.preferences.formatOnSave）
Plug('nvim-tree/nvim-tree.lua')                                                                      -- 文件树
Plug('nvim-tree/nvim-web-devicons')                                                                  -- 提供文件树图标
-- Plug('folke/lazydev.nvim')                                                                           -- 提供完整的nvim lua API 的代码补全
vim.call('plug#end')


-- ==========================================
-- 加载插件模块配置 (Plugins)
-- ==========================================
-- 让模块化配置生效，自动引入对应文件
require('plugins.ui')
-- require('plugins.coc')
-- require('plugins.nerdtree')
require('plugins.markdown')
-- require('plugins.ale')
require('plugins.undotree')
require('plugins.vimwiki')
require('plugins.tools')
require('plugins.nvim-dap')
require('plugins.nvim-notify')
require('plugins.nvim-cmp')
require('plugins.conform')
require('plugins.nvim-tree')
require('plugins.tools')
require('plugins.mason')


-- ==========================================
-- 一键编译运行 (Compile & Run)
-- ==========================================
local function compile_run()
  -- 保存当前文件
  vim.cmd('write')
  -- 获取当前文件信息
  local ft = vim.bo.filetype
  local file = vim.fn.expand('%')          -- 等价于 Vimscript 的 % (例如 main.c)
  local file_no_ext = vim.fn.expand('%:r') -- 等价于 Vimscript 的 %< (例如 main)
  -- 根据文件类型执行相应操作
  if ft == 'c' then
    vim.opt.splitbelow = true
    vim.cmd('split | resize -5')
    vim.cmd('term gcc ' .. file .. ' -o ' .. file_no_ext .. ' && time ./' .. file_no_ext)
  elseif ft == 'cpp' then
    vim.opt.splitbelow = true
    vim.cmd('!g++ -std=c++11 ' .. file .. ' -Wall -o ' .. file_no_ext)
    vim.cmd('split | resize -15')
    vim.cmd('term ./' .. file_no_ext)
  elseif ft == 'cs' then
    vim.opt.splitbelow = true
    vim.cmd('silent! !mcs ' .. file)
    vim.cmd('split | resize -5')
    vim.cmd('term mono ' .. file_no_ext .. '.exe')
  elseif ft == 'java' then
    vim.opt.splitbelow = true
    vim.cmd('split | resize -5')
    vim.cmd('term javac ' .. file .. ' && time java ' .. file_no_ext)
  elseif ft == 'sh' then
    vim.cmd('!time bash ' .. file)
  elseif ft == 'python' then
    vim.opt.splitbelow = true
    vim.cmd('split')
    vim.cmd('term python3 ' .. file)
  elseif ft == 'html' then
    -- 尝试获取全局变量，如果不存在则回退为默认的 firefox
    local browser = vim.g.mkdp_browser or 'firefox'
    vim.cmd('silent! !' .. browser .. ' ' .. file .. ' &')
  elseif ft == 'markdown' then
    vim.cmd('InstantMarkdownPreview')
  elseif ft == 'tex' then
    vim.cmd('silent! VimtexStop')
    vim.cmd('silent! VimtexCompile')
  elseif ft == 'dart' then
    local device = vim.g.flutter_default_device or ''
    local args = vim.g.flutter_run_args or ''
    vim.cmd('CocCommand flutter.run -d ' .. device .. ' ' .. args)
    vim.cmd('silent! CocCommand flutter.dev.openDevLog')
  elseif ft == 'javascript' then
    vim.opt.splitbelow = true
    vim.cmd('split')
    vim.cmd('term export DEBUG="INFO,ERROR,WARNING"; node --trace-warnings .')
  elseif ft == 'racket' then
    vim.opt.splitbelow = true
    vim.cmd('split | resize -5')
    vim.cmd('term racket ' .. file)
  elseif ft == 'go' then
    vim.opt.splitbelow = true
    vim.cmd('split')
    vim.cmd('term go run .')
  else
    -- 增加了一个友好的提示，如果遇到没配置过的语言会告诉你
    print("未配置一键运行命令的文件类型: " .. ft)
  end
end

-- 绑定快捷键 '<F10>' 到上面的函数
vim.keymap.set('n', '<F10>', compile_run, { noremap = true, silent = true, desc = "一键编译运行当前文件" })
