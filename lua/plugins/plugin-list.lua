return {
  -- ==========================================
  -- UI 与主题美化类
  -- ==========================================
  {
    "vim-airline/vim-airline",
    dependencies = { "vim-airline/vim-airline-themes" },
    config = function()
      require('config.ui')
    end
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,    -- 主题插件必须在启动时马上加载
    priority = 1000, -- 给予最高优先级
  },
  {
    "preservim/vim-indent-guides",
    event = "BufReadPre", -- 在读取文件时按需加载
  },
  {
    "junegunn/goyo.vim",
    cmd = "Goyo", -- 输入 :Goyo 命令时才加载
  },

  -- ==========================================
  -- 侧边栏与文件树
  -- ==========================================
  {
    "nvim-tree/nvim-tree.lua",
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
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    keys = { { "L", "<cmd>UndotreeToggle<cr>", desc = "Toggle UndoTree" } },
    config = function()
      require('config.undotree')
    end
  },
  {
    "preservim/tagbar",
    cmd = "TagbarOpenAutoClose",
    keys = { { "T", "<cmd>TagbarOpenAutoClose<cr>", desc = "Toggle Tagbar" } },
  },

  -- ==========================================
  -- 核心语言支持 (LSP, 补全, 调试)
  -- ==========================================
  {
    "williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "neovim/nvim-lspconfig",
    },
    config = function()
      require('config.mason')
    end
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "onsails/lspkind.nvim",
    },
    config = function()
      require('config.nvim-cmp')
    end
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    config = function()
      require('config.conform')
    end
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("config.nvim-treesitter")
    end
  },
  {
    "mfussenegger/nvim-dap",
    ft = { "python", "cpp", "cuda", 'c' },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "mfussenegger/nvim-dap-python",
    },
    config = function()
      require('config.debugging')
    end
  },

  -- ==========================================
  -- Markdown 与笔记 (VimWiki)
  -- ==========================================
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = "cd app && npm install",
    config = function()
      require('config.markdown')
    end
  },
  {
    "vimwiki/vimwiki",
    ft = "vimwiki",
    config = function()
      require('config.vimwiki')
    end
  },
  {
    "iamcco/mathjax-support-for-mkdp",
    ft = "markdown",
  },
  {
    "img-paste-devs/img-paste.vim",
    ft = "markdown",
  },

  -- ==========================================
  -- Git 与协同
  -- ==========================================
  { "tpope/vim-fugitive" },
  { "mhinz/vim-signify" },
  { "rhysd/conflict-marker.vim" },
  { "gisphm/vim-gitignore",     ft = "gitignore" },

  -- ==========================================
  -- 文本编辑与小工具
  -- ==========================================
  {
    "folke/noice.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      {
        "rcarriga/nvim-notify",
        config = function()
          require('config.nvim-notify')
        end
      }
    },
    event = "VeryLazy",
  },
  { "itchyny/vim-cursorword",       event = "VeryLazy" },
  { "tpope/vim-surround",           event = "VeryLazy" },
  { "godlygeek/tabular",            cmd = "Tabularize" },
  { "gcmt/wildfire.vim",            event = "VeryLazy" },
  { "scrooloose/nerdcommenter",     event = "VeryLazy" },
  { "terryma/vim-multiple-cursors", event = "VeryLazy" },
  { "dhruvasagar/vim-table-mode",   cmd = "TableModeToggle" },
  { "fadein/vim-FIGlet",            cmd = "FIGlet" },
  {
    "kshenoy/vim-signature",
    event = "BufReadPost",
    config = function()
      require('config.tools')
    end
  },

  -- ==========================================
  -- 语言特定优化 (杂项)
  -- ==========================================
  { "elzr/vim-json",                ft = "json" },
  { "hail2u/vim-css3-syntax",       ft = "css" },
  { "spf13/PIV",                    ft = "php" },
  { "gko/vim-coloresque",           ft = { "php", "html", "javascript", "css", "less" } },
  { "pangloss/vim-javascript",      ft = "javascript" },
  { "mattn/emmet-vim",              ft = { "html", "css", "javascript" } },
  { "vim-scripts/indentpython.vim", ft = "python" },
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
  },
  { "Bilal2453/luvit-meta",        lazy = true }, -- 解析 vim.uv 必须的依赖

  -- 底层依赖插件 (不需要单独配置)
  { "MarcWeber/vim-addon-mw-utils" },
  { "kana/vim-textobj-user" },
}
