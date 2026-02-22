-- 禁用 netrw (Vim 默认的文件浏览器，避免与 nvim-tree 冲突)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true

local api = require("nvim-tree.api")

-- ==========================================
-- 自定义快捷键绑定函数 (对应 coc-explorer.keyMappings)
-- ==========================================
local function my_on_attach(bufnr)
  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  -- ================= 导航与打开 =================
  vim.keymap.set('n', '<CR>', api.node.open.edit, opts('open: 展开目录或打开文件'))
  vim.keymap.set('n', 'i', api.node.open.vertical, opts('open:vsplit: 垂直分屏打开文件'))
  vim.keymap.set('n', 'o', api.node.open.tab, opts('open:tab: 在新标签页打开文件'))
  vim.keymap.set('n', 'n', api.node.navigate.parent_close, opts('collapse: 折叠当前目录'))
  vim.keymap.set('n', '<BS>', api.tree.change_root_to_parent, opts('gotoParent: 将父目录作为新的根目录'))
  vim.keymap.set('n', 'q', api.tree.close, opts('quit: 关闭文件树'))
  vim.keymap.set('n', '?', api.tree.toggle_help, opts('help: 查看快捷键帮助'))
  vim.keymap.set('n', 'R', api.tree.reload, opts('refresh: 刷新文件树'))
  vim.keymap.set('n', '.', api.tree.toggle_hidden_filter, opts('toggleHidden: 切换显示/隐藏文件'))
  vim.keymap.set('n', 'zh', api.tree.toggle_hidden_filter, opts('toggleHidden: 切换显示/隐藏文件'))
  vim.keymap.set('n', 'X', api.node.run.system, opts('systemExecute: 使用系统默认应用打开'))

  -- ================= 文件操作 =================
  vim.keymap.set('n', 'a', api.fs.create, opts('addFile/Dir: 新建文件或目录 (以/结尾即为目录)'))
  vim.keymap.set('n', 'M', api.fs.create, opts('addDirectory: 新建文件或目录 (同a)'))
  vim.keymap.set('n', 'rn', api.fs.rename, opts('rename: 重命名节点'))
  vim.keymap.set('n', 'dD', api.fs.remove, opts('deleteForever: 永久删除文件/目录'))

  -- 剪贴板操作 (对应 yy, dd, pp, yn, yp)
  vim.keymap.set('n', 'yy', api.fs.copy.node, opts('copyFile: 复制节点 (到内部剪贴板)'))
  vim.keymap.set('n', 'dd', api.fs.cut, opts('cutFile: 剪切节点'))
  vim.keymap.set('n', 'pp', api.fs.paste, opts('pasteFile: 粘贴节点'))
  vim.keymap.set('n', 'yp', api.fs.copy.absolute_path, opts('copyFilepath: 复制绝对路径到系统剪贴板'))
  vim.keymap.set('n', 'yn', api.fs.copy.filename, opts('copyFilename: 复制文件名到系统剪贴板'))

  -- ================= 搜索与跳转 =================
  vim.keymap.set('n', 'f', api.tree.search_node, opts('search: 搜索当前目录'))
  vim.keymap.set('n', 's', api.marks.toggle, opts('toggleSelection: 标记/取消标记(多选)节点'))

  -- ================= 诊断与 Git =================
  vim.keymap.set('n', '[c', api.node.navigate.git.prev, opts('gitPrev: 跳转到上一个 Git 更改节点'))
  vim.keymap.set('n', ']c', api.node.navigate.git.next, opts('gitNext: 跳转到下一个 Git 更改节点'))
  vim.keymap.set('n', '[d', api.node.navigate.diagnostics.prev, opts('diagnosticPrev: 跳转到上一个诊断错误节点'))
  vim.keymap.set('n', ']d', api.node.navigate.diagnostics.next, opts('diagnosticNext: 跳转到下一个诊断错误节点'))
end

require("nvim-tree").setup({
  on_attach = my_on_attach,

  -- 对应 "explorer.file.showHiddenFiles": false
  filters = {
    dotfiles = true,
    custom = { "^.git$" },
  },

  -- 对应 "explorer.file.column.indent.indentLine": true
  renderer = {
    indent_markers = {
      enable = true,
      icons = { corner = "└", edge = "│", item = "│", none = " " },
    },
    -- 对应 "explorer.icon.enableNerdfont": true
    icons = {
      show = { file = true, folder = true, folder_arrow = true, git = true },
      glyphs = {
        default = "",
        symlink = "",
        folder = {
          arrow_closed = "❯",
          arrow_open = "▼",
          default = "",
          open = "",
          empty = "",
          empty_open = "",
          symlink = "",
          symlink_open = "",
        },
      },
    },
  },

  actions = {
    open_file = {
      quit_on_open = false,
      window_picker = { enable = false },
    },
  },

  diagnostics = {
    enable = true,
    show_on_dirs = true,
    show_on_open_dirs = true,
    icons = { hint = "\u{f864}", info = "\u{f129}", warning = "\u{f071}", error = "\u{f467}" },
  },

  view = { width = 30, side = "left" },
})

-- 全局快捷键：随时随地呼出/关闭文件树
-- vim.keymap.set('n', 'tt', ':NvimTreeToggle<CR>', { noremap = true, silent = true, desc = "切换文件树" })
-- vim.keymap.set('n', '<leader>f', ':NvimTreeFindFile<CR>', { noremap = true, silent = true, desc = "在文件树中定位当前文件" })
