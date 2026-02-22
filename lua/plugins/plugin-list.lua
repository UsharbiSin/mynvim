-- ==========================================
-- ~/.config/nvim/lua/plugins/plugin-list.lua
-- 专门管理所有的插件声明与依赖关系 (带中文注释版)
-- ==========================================

return {
  -- ==========================================
  -- UI 与主题美化类
  -- ==========================================
  {
    "vim-airline/vim-airline", -- 美化底部状态栏
    dependencies = { "vim-airline/vim-airline-themes" },
    config = function()
      require('config.ui')
    end
  },
  {
    "folke/tokyonight.nvim", -- 色彩主题
    lazy = false,            -- 主题插件必须在启动时马上加载
    priority = 1000,         -- 给予最高优先级
  },
  {
    "preservim/vim-indent-guides", -- 可视化显示缩进级别
    event = "BufReadPre",          -- 在读取文件时按需加载
  },
  {
    "junegunn/goyo.vim", -- 沉浸式专注写作模式
    cmd = "Goyo",        -- 输入 :Goyo 命令时才加载
  },

  -- ==========================================
  -- 侧边栏与文件树
  -- ==========================================
  {
    "nvim-tree/nvim-tree.lua", -- 文件树
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "tt", "<cmd>NvimTreeToggle<CR>", desc = "打开/关闭文件树" },
      { "<leader>f", "<cmd>NvimTreeFindFile<CR>", desc = "在文件树中定位当前文件" }
    },
    config = function()
      require('config.nvim-tree')
    end
  },
  {
    "mbbill/undotree", -- 可视化撤销历史树
    cmd = "UndotreeToggle",
    keys = { { "L", "<cmd>UndotreeToggle<cr>", desc = "Toggle UndoTree" } },
    config = function()
      require('config.undotree')
    end
  },
  {
    "preservim/tagbar", -- 侧边栏函数大纲
    cmd = "TagbarOpenAutoClose",
    keys = { { "T", "<cmd>TagbarOpenAutoClose<cr>", desc = "Toggle Tagbar" } },
  },

  -- ==========================================
  -- 核心语言支持 (LSP, 补全, 调试)
  -- ==========================================
  {
    "williamboman/mason.nvim",             -- LSP/Linter/Formatter 安装管理器
    dependencies = {
      "williamboman/mason-lspconfig.nvim", -- 桥接 mason 和 lspconfig
      "neovim/nvim-lspconfig",             -- 原生 LSP 核心配置
    },
    config = function()
      require('config.mason')
    end
  },
  {
    "hrsh7th/nvim-cmp",       -- 补全引擎核心
    dependencies = {
      "hrsh7th/cmp-nvim-lsp", -- LSP 补全源
      "hrsh7th/cmp-buffer",   -- Buffer 补全源
      "hrsh7th/cmp-path",     -- 路径补全源
      "onsails/lspkind.nvim", -- 补全菜单图标
    },
    config = function()
      require('config.nvim-cmp')
    end
  },
  {
    "stevearc/conform.nvim", -- 格式化代码工具
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    config = function()
      require('config.conform')
    end
  },
  {
    "nvim-treesitter/nvim-treesitter", -- 供nvim-dap-virtual-text查找变量定义
    build = ":TSUpdate",
    config = function()
      require("config.nvim-treesitter")
    end
  },
  {
    "mfussenegger/nvim-dap", -- debug辅助
    ft = { "python", "cpp", "cuda", 'c' },
    dependencies = {
      "nvim-neotest/nvim-nio",           -- 提供异步I/O功能
      "rcarriga/nvim-dap-ui",            -- 提供debug ui
      "theHamsta/nvim-dap-virtual-text", -- 调试时在行内显示变量值
      "mfussenegger/nvim-dap-python",    -- 桥接python-debugpy
    },
    config = function()
      require('config.debugging')
    end
  },

  -- ==========================================
  -- Markdown 与笔记 (VimWiki)
  -- ==========================================
  {
    "iamcco/markdown-preview.nvim", -- Markdown 浏览器实时预览
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = "cd app && npm install",
    config = function()
      require('config.markdown')
    end
  },
  {
    "vimwiki/vimwiki", -- 个人知识库系统
    ft = "vimwiki",
    config = function()
      require('config.vimwiki')
    end
  },
  {
    "iamcco/mathjax-support-for-mkdp", -- Markdown 数学公式支持
    ft = "markdown",
  },
  {
    "img-paste-devs/img-paste.vim", -- Markdown 剪贴板一键贴图
    ft = "markdown",
  },

  -- ==========================================
  -- Git 与协同
  -- ==========================================
  { "tpope/vim-fugitive" },                         -- Git 深度集成工具
  { "mhinz/vim-signify" },                          -- 侧边栏版本差异可视化
  { "rhysd/conflict-marker.vim" },                  -- 辅助解决 Git 合并冲突
  { "gisphm/vim-gitignore",     ft = "gitignore" }, -- 快速生成 .gitignore

  -- ==========================================
  -- 文本编辑与小工具
  -- ==========================================
  {
    "folke/noice.nvim",         -- 美化输入框
    dependencies = {
      "MunifTanjim/nui.nvim",   -- UI基础库插件，供noice.vim 依赖
      {
        "rcarriga/nvim-notify", -- 供noice.nvim 依赖，接管通知
        config = function()
          require('config.nvim-notify')
        end
      }
    },
    event = "VeryLazy",
  },
  { "itchyny/vim-cursorword",       event = "VeryLazy" },      -- 自动高亮当前光标下的单词
  { "tpope/vim-surround",           event = "VeryLazy" },      -- 快速增删改括号/引号等成对符号
  { "godlygeek/tabular",            cmd = "Tabularize" },      -- 强大的按符号对齐工具
  { "gcmt/wildfire.vim",            event = "VeryLazy" },      -- 回车键智能选中文本对象
  { "scrooloose/nerdcommenter",     event = "VeryLazy" },      -- 代码批量注释神器
  { "terryma/vim-multiple-cursors", event = "VeryLazy" },      -- 类似 Sublime 的多光标编辑
  { "dhruvasagar/vim-table-mode",   cmd = "TableModeToggle" }, -- 强大的表格自动排版
  { "fadein/vim-FIGlet",            cmd = "FIGlet" },          -- 生成 ASCII 艺术大字
  {
    "kshenoy/vim-signature",                                   -- 侧边栏书签标记显示
    event = "BufReadPost",
    config = function()
      require('config.tools')
    end
  },
  { "h-hg/fcitx.nvim" }, -- normal模式自动切换为英文

  -- ==========================================
  -- 语言特定优化 (杂项)
  -- ==========================================
  { "elzr/vim-json",                ft = "json" },                                         -- JSON 文件解析与优化
  { "hail2u/vim-css3-syntax",       ft = "css" },                                          -- CSS3 语法高亮优化
  { "spf13/PIV",                    ft = "php" },                                          -- PHP 优化
  { "gko/vim-coloresque",           ft = { "php", "html", "javascript", "css", "less" } }, -- 颜色代码实时预览
  { "pangloss/vim-javascript",      ft = "javascript" },                                   -- JS 优化
  { "mattn/emmet-vim",              ft = { "html", "css", "javascript" } },                -- HTML/CSS 代码快速生成
  { "vim-scripts/indentpython.vim", ft = "python" },                                       -- Python 自动缩进优化
  {
    "folke/lazydev.nvim",                                                                  -- 提供完整的nvim lua API 的代码补全
    ft = "lua",
    opts = {
      library = {
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
  },
  { "Bilal2453/luvit-meta",        lazy = true }, -- 解析 vim.uv 必须的依赖

  -- 底层依赖插件 (不需要单独配置)
  { "MarcWeber/vim-addon-mw-utils" }, -- 插件底层依赖
  { "kana/vim-textobj-user" },        -- 文本对象底层依赖
}
