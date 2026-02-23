vim.g.mapleader = " "

-- 禁用不需要的外部语言 Provider，保持 :checkhealth 满绿状态
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- ==========================================
-- 加载核心配置 (Core)
-- ==========================================
require('core.options')
require('core.keymaps')

-- ==========================================
-- Bootstrap 自动安装 lazy.nvim
-- ==========================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- 最新稳定版
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ==========================================
-- 启动 lazy.nvim，并告诉它去读取分离的声明列表
-- ==========================================
-- 这里的 "plugin-list" 对应下方新建的 lua/plugin-list.lua 文件
require("lazy").setup("plugins")

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
