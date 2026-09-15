-- 禁用 netrw (Vim 默认的文件浏览器，避免与 nvim-tree 冲突)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true

local api = require("nvim-tree.api")
local M = {}

-- nvim-tree 自身的节点高亮优先级为 200。之前只通过 Decorator 追加 ignored
-- 高亮时，会和文件名/DevIcon 的同优先级高亮竞争，实际终端里可能仍显示普通颜色。
-- 因此在每次 TreeRendered 后，用更高优先级覆盖整条 ignored 节点，确保稳定变淡。
local ignored_namespace = vim.api.nvim_create_namespace("NvimTreeGitIgnoredDim")

local function set_ignored_highlight()
  local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
  vim.api.nvim_set_hl(0, "NvimTreeGitIgnoredDim", { fg = comment.fg })
end

local function dim_ignored_nodes(payload)
  local bufnr = payload and payload.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

  local core = require("nvim-tree.core")
  local explorer = core.get_explorer()
  if not explorer then return end

  vim.api.nvim_buf_clear_namespace(bufnr, ignored_namespace, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local nodes_by_line = explorer:get_nodes_by_line(core.get_nodes_starting_line())
  for line, node in pairs(nodes_by_line) do
    if node:is_git_ignored() then
      local text = lines[line] or ""
      if text ~= "" then
        vim.api.nvim_buf_set_extmark(bufnr, ignored_namespace, line - 1, 0, {
          end_row = line - 1,
          end_col = #text,
          hl_group = "NvimTreeGitIgnoredDim",
          priority = 1000,
        })
      end
    end
  end
end

set_ignored_highlight()
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_ignored_highlight,
  desc = "更新 nvim-tree Git 忽略项的淡化颜色",
})
api.events.subscribe(api.events.Event.TreeRendered, dim_ignored_nodes)

function M.toggle_current_dir()
  if api.tree.is_visible() then
    api.tree.close()
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  local root
  if path ~= "" and vim.bo[buf].buftype == "" then
    local directory = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
    -- 仓库内统一使用 Git 根目录，避免在同一项目的子目录间切换时反复改变树根。
    root = vim.fs.root(directory, ".git") or directory
  end
  api.tree.open({ path = root or vim.fn.getcwd(), find_file = true })
end

-- ==========================================
-- 自定义快捷键绑定函数 (对应 coc-explorer.keyMappings)
-- ==========================================
local function my_on_attach(bufnr)
  local function opts(desc)
    return { desc = "文件树：" .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  -- ================= 导航与打开 =================
  vim.keymap.set('n', '<CR>', api.node.open.edit, opts('展开目录或打开文件'))
  vim.keymap.set('n', 'i', api.node.open.vertical, opts('垂直分屏打开文件'))
  vim.keymap.set('n', 'o', api.node.open.tab, opts('在新标签页打开文件'))
  vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts('折叠当前目录'))
  vim.keymap.set('n', '<BS>', api.tree.change_root_to_parent, opts('将父目录设为新的根目录'))
  vim.keymap.set('n', 'q', api.tree.close, opts('关闭文件树'))
  vim.keymap.set('n', '?', api.tree.toggle_help, opts('查看快捷键帮助'))
  vim.keymap.set('n', 'R', api.tree.reload, opts('刷新文件树'))
  vim.keymap.set('n', '.', api.filter.dotfiles.toggle, opts('开关显示隐藏文件'))
  vim.keymap.set('n', 'zh', api.filter.dotfiles.toggle, opts('开关显示隐藏文件'))
  vim.keymap.set('n', 'I', api.filter.git.ignored.toggle, opts('开关显示 Git 忽略文件'))
  vim.keymap.set('n', 'X', api.node.run.system, opts('使用系统默认应用打开'))

  -- ================= 文件操作 =================
  vim.keymap.set('n', 'a', api.fs.create, opts('新建文件或目录（以 / 结尾即为目录）'))
  vim.keymap.set('n', 'M', api.fs.create, opts('新建文件或目录（同 a）'))
  vim.keymap.set('n', 'rn', api.fs.rename, opts('重命名节点'))
  vim.keymap.set('n', 'dD', api.fs.remove, opts('永久删除文件或目录'))

  -- 剪贴板操作 (对应 yy, dd, pp, yn, yp)
  vim.keymap.set('n', 'yy', api.fs.copy.node, opts('复制节点到内部剪贴板'))
  vim.keymap.set('n', 'dd', api.fs.cut, opts('剪切节点'))
  vim.keymap.set('n', 'pp', api.fs.paste, opts('粘贴节点'))
  vim.keymap.set('n', 'yp', api.fs.copy.absolute_path, opts('复制绝对路径到系统剪贴板'))
  vim.keymap.set('n', 'yn', api.fs.copy.filename, opts('复制文件名到系统剪贴板'))

  -- ================= 搜索与跳转 =================
  vim.keymap.set('n', 'f', api.tree.search_node, opts('搜索当前目录'))
  vim.keymap.set('n', 's', api.marks.toggle, opts('标记或取消标记节点（多选）'))

  -- ================= 诊断与 Git =================
  vim.keymap.set('n', '[c', api.node.navigate.git.prev, opts('跳转到上一个 Git 更改节点'))
  vim.keymap.set('n', ']c', api.node.navigate.git.next, opts('跳转到下一个 Git 更改节点'))
  vim.keymap.set('n', '[d', api.node.navigate.diagnostics.prev, opts('跳转到上一个诊断节点'))
  vim.keymap.set('n', ']d', api.node.navigate.diagnostics.next, opts('跳转到下一个诊断节点'))
end

require("nvim-tree").setup({
  on_attach = my_on_attach,

  -- 对应 "explorer.file.showHiddenFiles": false
  filters = {
    dotfiles = true,
    -- 默认显示 .gitignore 忽略项；按 I 可临时隐藏/重新显示。
    git_ignored = false,
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
        git = {
          ignored = "",
        },
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
    icons = { hint = "\u{f0335}", info = "\u{f129}", warning = "\u{f071}", error = "\u{f467}" },
  },

  view = { width = 30, side = "left" },
})

-- 全局快捷键：随时随地呼出/关闭文件树
-- vim.keymap.set('n', 'tt', ':NvimTreeToggle<CR>', { noremap = true, silent = true, desc = "切换文件树" })
-- vim.keymap.set('n', '<leader>f', ':NvimTreeFindFile<CR>', { noremap = true, silent = true, desc = "在文件树中定位当前文件" })

return M
