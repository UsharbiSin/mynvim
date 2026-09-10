# 插件分类与单独说明

[返回项目使用说明](../README.md)

本索引按实际用途分类。每个插件有独立 Markdown，内容区分“上游能力”和“本项目确实启用
的能力”。平台独有项通过运行时条件加载并已标注。

内置的 [Office 文档支持](office.md)不新增重复的图片插件，负责 DOCX/XLSX/PPTX/PDF
预览、OOXML 安全保存、跨平台依赖和已知限制。

## UI 与显示

- [vim-airline](plugins/ui/vim-airline.md)：底部状态栏
- [vim-airline-themes](plugins/ui/vim-airline-themes.md)：Airline 主题集合
- [tokyonight.nvim](plugins/ui/tokyonight.nvim.md)：主配色
- [indent-blankline.nvim](plugins/ui/indent-blankline.nvim.md)：缩进引导线与当前语法作用域
- [goyo.vim](plugins/ui/goyo.vim.md)：专注写作
- [noice.nvim](plugins/ui/noice.nvim.md)：消息、命令行 UI
- [nui.nvim](plugins/ui/nui.nvim.md)：Noice 的 UI 依赖
- [nvim-notify](plugins/ui/nvim-notify.md)：通知窗口
- [which-key.nvim](plugins/ui/which-key.nvim.md)：按键提示

## 文件、结构与历史导航

- [nvim-tree.lua](plugins/navigation/nvim-tree.lua.md)：文件树
- [nvim-web-devicons](plugins/navigation/nvim-web-devicons.md)：文件图标
- [undotree](plugins/navigation/undotree.md)：撤销历史树
- [tagbar](plugins/navigation/tagbar.md)：基于 tags 的代码大纲

## LSP、补全、格式化与语言支持

- [mason.nvim](plugins/language/mason.nvim.md) / [mason-lspconfig.nvim](plugins/language/mason-lspconfig.nvim.md)
- [nvim-lspconfig](plugins/language/nvim-lspconfig.md)
- [LspProxy](plugins/language/lsp-proxy.md)：LSP 文档中文翻译
- [nvim-cmp](plugins/language/nvim-cmp.md)、[cmp-nvim-lsp](plugins/language/cmp-nvim-lsp.md)、[cmp-buffer](plugins/language/cmp-buffer.md)、[cmp-path](plugins/language/cmp-path.md)、[lspkind.nvim](plugins/language/lspkind.nvim.md)
- [conform.nvim](plugins/language/conform.nvim.md) / [nvim-lint](plugins/language/nvim-lint.md)
- [nvim-treesitter](plugins/language/nvim-treesitter.md)
- [sqls.nvim](plugins/language/sqls.nvim.md)
- [dadbod-grip.nvim](plugins/language/dadbod-grip.nvim.md)
- [lazydev.nvim](plugins/language/lazydev.nvim.md) / [luvit-meta](plugins/dependencies/luvit-meta.md)
- [vim-json](plugins/language/vim-json.md)、[vim-css3-syntax](plugins/language/vim-css3-syntax.md)、[PIV](plugins/language/PIV.md)、[vim-coloresque](plugins/language/vim-coloresque.md)、[vim-javascript](plugins/language/vim-javascript.md)、[emmet-vim](plugins/language/emmet-vim.md)、[indentpython.vim](plugins/language/indentpython.vim.md)

## 调试

- [nvim-dap](plugins/debugging/nvim-dap.md)：调试协议核心
- [nvim-dap-ui](plugins/debugging/nvim-dap-ui.md)：调试布局
- [nvim-dap-virtual-text](plugins/debugging/nvim-dap-virtual-text.md)：行内变量值
- [nvim-dap-python](plugins/debugging/nvim-dap-python.md)：Python 辅助层（已安装但当前未调用 setup）
- [nvim-nio](plugins/dependencies/nvim-nio.md)：DAP UI 异步依赖

## Markdown 与知识库

- [render-markdown.nvim](plugins/markdown/render-markdown.nvim.md)：编辑器内渲染
- [otter.nvim](plugins/markdown/otter.nvim.md)：围栏代码的 LSP 功能
- [markdown-preview.nvim](plugins/markdown/markdown-preview.nvim.md)：浏览器预览
- [vimwiki](plugins/markdown/vimwiki.md)：个人知识库
- [mathjax-support-for-mkdp](plugins/markdown/mathjax-support-for-mkdp.md)：旧预览方案的数学扩展
- [img-clip.nvim](plugins/markdown/img-clip.nvim.md)：剪贴板图片保存
- [diagram.nvim](plugins/markdown/diagram.nvim.md)：代码块图表渲染
- [bullets.vim](plugins/markdown/bullets.vim.md)：列表续写
- [vim-table-mode](plugins/markdown/vim-table-mode.md)：表格输入和排版
- [snacks.nvim](plugins/markdown/snacks.nvim.md)：行内图片、公式与 Codex 终端
- [mini.nvim](plugins/dependencies/mini.nvim.md)：render-markdown 图标依赖
- [image.nvim](plugins/dependencies/image.nvim.md)：diagram.nvim 图像后端

## Git

- [vim-fugitive](plugins/git/vim-fugitive.md)
- [gitsigns.nvim](plugins/git/gitsigns.nvim.md)
- [conflict-marker.vim](plugins/git/conflict-marker.vim.md)
- [vim-gitignore](plugins/git/vim-gitignore.md)

## 文本编辑与小工具

- [vim-cursorword](plugins/editing/vim-cursorword.md)
- [vim-surround](plugins/editing/vim-surround.md)
- [tabular](plugins/editing/tabular.md)
- [wildfire.vim](plugins/editing/wildfire.vim.md)
- [nerdcommenter](plugins/editing/nerdcommenter.md)
- [vim-multiple-cursors](plugins/editing/vim-multiple-cursors.md)
- [vim-FIGlet](plugins/editing/vim-FIGlet.md)
- [vim-signature](plugins/editing/vim-signature.md)
- [boole.nvim](plugins/editing/boole.nvim.md)
- [csvview.nvim](plugins/editing/csvview.nvim.md)：Office XLSX 表格显示和单元格导航

## 输入法

- [fcitx.nvim](plugins/input/fcitx.nvim.md)（仅 Linux 加载）
- [im-select.nvim](plugins/input/im-select.nvim.md)（仅 Windows 加载）

## 底层依赖和插件管理器

- [lazy.nvim](plugins/dependencies/lazy.nvim.md)
- [vim-addon-mw-utils](plugins/dependencies/vim-addon-mw-utils.md)
- [vim-textobj-user](plugins/dependencies/vim-textobj-user.md)
- [nvim-nio](plugins/dependencies/nvim-nio.md)
- [mini.nvim](plugins/dependencies/mini.nvim.md)
- [luvit-meta](plugins/dependencies/luvit-meta.md)
- [image.nvim](plugins/dependencies/image.nvim.md)

## 两个容易误判的文件

`lua/config/coc.lua` 和 `lua/config/nerdtree.lua` 是历史配置文件，但当前插件清单没有声明
`coc.nvim` 或 `NERDTree`，启动链也不 require 它们。本文档不把这两项列为已安装插件。
