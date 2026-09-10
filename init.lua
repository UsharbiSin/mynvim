vim.g.mapleader = " "

-- 禁用不需要的外部语言 Provider，保持 :checkhealth 满绿状态
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

vim.g.is_win = vim.fn.has("win32")

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
-- 通过 pkg.sources 拦截，不加载任何带有 rockspec 的包管理源（windows 下会出问题）
local lazy_opts = {}

if vim.g.is_win == 1 then
  lazy_opts.rocks = { hererocks = false, enabled = false }
  lazy_opts.pkg = { sources = { "lazy" } }
end
-- 这里的 "plugin-list" 对应下方新建的 lua/plugin-list.lua 文件
require("lazy").setup("plugins", lazy_opts)

-- Office 文档预览与轻度编辑使用独立模块，不影响普通文本缓冲区。
require('office').setup()

-- 一键编译运行；参数以 argv 传递，兼容 Windows 路径和 PowerShell。
vim.keymap.set('n', '<F10>', require("core.runner").run_current,
  { noremap = true, silent = true, desc = "一键编译运行当前文件" })

-- =======================================================
-- Windows 下强制让 Neovim 使用 PowerShell 执行系统命令
-- =======================================================
if vim.g.is_win == 1 then
  local powershell_options = {
    shell = vim.fn.executable("pwsh") == 1 and "pwsh" or "powershell",
    shellcmdflag = "-NoProfile -NoLogo -ExecutionPolicy RemoteSigned -Command ",
    shellxquote = "",
    shellquote = "",
    shellpipe = "| out-file -encoding UTF8 ",
    shellredir = "2>&1 | out-file -encoding UTF8 ",
  }

  for option, value in pairs(powershell_options) do
    vim.opt[option] = value
  end
end
