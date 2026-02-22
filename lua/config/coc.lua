-- 较长的 updatetime（默认 4000 毫秒 = 4 秒）会导致明显的延迟和糟糕的用户体验
vim.opt.updatetime = 100

-- 始终显示标记列（signcolumn），否则每次出现/解决诊断报错时文本都会发生平移
vim.opt.signcolumn = "yes"

local keyset = vim.keymap.set

-- ==========================================
-- 自动补全 (Autocomplete)
-- ==========================================
function _G.check_back_space()
  local col = vim.fn.col('.') - 1
  return col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') ~= nil
end

-- 使用 Tab 键触发补全并在列表中向下导航
-- NOTE: 默认情况下总是会自动选中第一个补全项，如果你想关闭自动选中，
-- 可以在 coc-settings.json 中设置 `"suggest.noselect": true`
-- NOTE: 在将此配置放入配置之前，请使用命令 ':verbose imap <tab>' 确保 Tab 键没有被其他插件占用
local opts = { silent = true, noremap = true, expr = true, replace_keycodes = false }
keyset("i", "<TAB>", [[coc#pum#visible() ? coc#pum#next(1) : "\<Tab>"]], opts)
keyset("i", "<S-TAB>", [[coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"]], opts)

-- 让回车键 <CR> 接受选中的补全项，或者通知 coc.nvim 进行代码格式化
-- <C-g>u 会打断当前的撤销序列（undo sequence），请根据自己的喜好选择
keyset("i", "<cr>", [[coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"]], opts)

-- 使用 <c-j> 触发代码片段
keyset("i", "<c-j>", "<Plug>(coc-snippets-expand-jump)")
-- 使用 <M-/> (Alt+/) 手动强制触发补全提示 (定制你的专属快捷键)
keyset("i", "<M-/>", "coc#refresh()", { silent = true, expr = true })


-- ==========================================
-- 诊断与跳转 (Diagnostics & Navigation)
-- ==========================================
-- 使用 `[g` 和 `]g` 在诊断报错/警告之间快速导航跳转
-- 使用 `:CocDiagnostics` 可以在位置列表中获取当前缓冲区的所有诊断信息
keyset("n", "[g", "<Plug>(coc-diagnostic-prev)", { silent = true })
keyset("n", "]g", "<Plug>(coc-diagnostic-next)", { silent = true })

-- 代码跳转导航
keyset("n", "gd", "<Plug>(coc-definition)", { silent = true })
keyset("n", "gy", "<Plug>(coc-type-definition)", { silent = true })
keyset("n", "gi", "<Plug>(coc-implementation)", { silent = true })
keyset("n", "gr", "<Plug>(coc-references)", { silent = true })

-- 使用大写 K 在预览窗口中显示光标下符号的文档注释 (定制你的专属快捷键)
function _G.show_docs()
  local cw = vim.fn.expand('<cword>')
  if vim.fn.index({ 'vim', 'help' }, vim.bo.filetype) >= 0 then
    vim.api.nvim_command('h ' .. cw)
  elseif vim.api.nvim_eval('coc#rpc#ready()') then
    vim.fn.CocActionAsync('doHover')
  else
    vim.api.nvim_command('!' .. vim.o.keywordprg .. ' ' .. cw)
  end
end

keyset("n", "K", '<CMD>lua _G.show_docs()<CR>', { silent = true })

-- 当光标在某个符号上静止停留时，高亮显示该符号及其在文中的所有引用
vim.api.nvim_create_augroup("CocGroup", {})
vim.api.nvim_create_autocmd("CursorHold", {
  group = "CocGroup",
  command = "silent call CocActionAsync('highlight')",
  desc = "Highlight symbol under cursor on CursorHold"
})


-- ==========================================
-- 代码操作与重构 (Refactoring & Formatting)
-- ==========================================
-- 符号重命名 (变量/函数重命名)
keyset("n", "<leader>rn", "<Plug>(coc-rename)", { silent = true })

-- 格式化选中的代码
keyset("x", "<leader>f", "<Plug>(coc-format-selected)", { silent = true })
keyset("n", "<leader>f", "<Plug>(coc-format-selected)", { silent = true })

-- 为指定的文件类型（如 typescript, json）设置 formatexpr 格式化表达式
vim.api.nvim_create_autocmd("FileType", {
  group = "CocGroup",
  pattern = "typescript,json",
  command = "setl formatexpr=CocAction('formatSelected')",
  desc = "Setup formatexpr specified filetype(s)."
})

-- 将代码操作 (Code Action) 应用于选中的代码块
-- 示例：使用 `<leader>aap` 将操作应用于当前段落
local action_opts = { silent = true, nowait = true }
keyset("x", "<leader>a", "<Plug>(coc-codeaction-selected)", action_opts)
keyset("n", "<leader>a", "<Plug>(coc-codeaction-selected)", action_opts)

-- 重新映射按键，用于在当前光标位置应用代码操作 (例如自动导入包)
keyset("n", "<leader>ac", "<Plug>(coc-codeaction-cursor)", action_opts)
-- 重新映射按键，用于应用影响整个缓冲区的代码操作
keyset("n", "<leader>as", "<Plug>(coc-codeaction-source)", action_opts)
-- 应用最优的快速修复 (quickfix) 操作，以修复当前行的诊断报错
keyset("n", "<leader>qf", "<Plug>(coc-fix-current)", action_opts)

-- 重新映射按键，用于应用重构相关的代码操作
keyset("n", "<leader>re", "<Plug>(coc-codeaction-refactor)", { silent = true })
keyset("x", "<leader>r", "<Plug>(coc-codeaction-refactor-selected)", { silent = true })
keyset("n", "<leader>r", "<Plug>(coc-codeaction-refactor-selected)", { silent = true })

-- 在当前行运行 Code Lens 操作
keyset("n", "<leader>cl", "<Plug>(coc-codelens-action)", action_opts)


-- ==========================================
-- 文本对象与进阶选择 (Text Objects & Selection)
-- ==========================================
-- 映射函数和类的文本对象 (Text objects)
-- 注意：需要语言服务器支持 'textDocument.documentSymbol' 功能
keyset("x", "if", "<Plug>(coc-funcobj-i)", action_opts)
keyset("o", "if", "<Plug>(coc-funcobj-i)", action_opts)
keyset("x", "af", "<Plug>(coc-funcobj-a)", action_opts)
keyset("o", "af", "<Plug>(coc-funcobj-a)", action_opts)
keyset("x", "ic", "<Plug>(coc-classobj-i)", action_opts)
keyset("o", "ic", "<Plug>(coc-classobj-i)", action_opts)
keyset("x", "ac", "<Plug>(coc-classobj-a)", action_opts)
keyset("o", "ac", "<Plug>(coc-classobj-a)", action_opts)

-- 重新映射 <C-f> 和 <C-b>，用于向下/向上滚动悬浮窗口或弹出菜单
---@diagnostic disable-next-line: redefined-local
local scroll_opts = { silent = true, nowait = true, expr = true }
keyset("n", "<C-f>", 'coc#float#has_scroll() ? coc#float#scroll(1) : "<C-f>"', scroll_opts)
keyset("n", "<C-b>", 'coc#float#has_scroll() ? coc#float#scroll(0) : "<C-b>"', scroll_opts)
keyset("i", "<C-f>", 'coc#float#has_scroll() ? "<c-r>=coc#float#scroll(1)<cr>" : "<Right>"', scroll_opts)
keyset("i", "<C-b>", 'coc#float#has_scroll() ? "<c-r>=coc#float#scroll(0)<cr>" : "<Left>"', scroll_opts)
keyset("v", "<C-f>", 'coc#float#has_scroll() ? coc#float#scroll(1) : "<C-f>"', scroll_opts)
keyset("v", "<C-b>", 'coc#float#has_scroll() ? coc#float#scroll(0) : "<C-b>"', scroll_opts)

-- 使用 CTRL-l 智能选择代码范围 (Selections ranges) (定制你的专属快捷键)
-- 需要语言服务器支持 'textDocument/selectionRange' 功能
keyset("n", "<C-l>", "<Plug>(coc-range-select)", { silent = true })
keyset("x", "<C-l>", "<Plug>(coc-range-select)", { silent = true })


-- ==========================================
-- 自定义命令与面板 (Commands & CocList)
-- ==========================================
-- 添加 `:Format` 命令来格式化当前整个缓冲区
vim.api.nvim_create_user_command("Format", "call CocAction('format')", {})

-- 添加 `:Fold` 命令来折叠当前缓冲区
vim.api.nvim_create_user_command("Fold", "call CocAction('fold', <f-args>)", { nargs = '?' })

-- 添加 `:OR` 命令来自动整理当前缓冲区的 import 导入 (Organize Imports)
vim.api.nvim_create_user_command("OR", "call CocActionAsync('runCommand', 'editor.action.organizeImport')", {})

-- 添加 (Neo)Vim 的原生状态栏支持
-- NOTE: 因为你已经使用了 vim-airline，这里将其注释掉以免冲突
-- vim.opt.statusline:prepend("%{coc#status()}%{get(b:,'coc_current_function','')}")

-- CoCList 的快捷键映射 (弹出式搜索面板)
---@diagnostic disable-next-line: redefined-local
local list_opts = { silent = true, nowait = true }
-- 呼出所有诊断报错列表
keyset("n", "<space>a", ":<C-u>CocList diagnostics<cr>", list_opts)
-- 管理 coc 扩展
keyset("n", "<space>e", ":<C-u>CocList extensions<cr>", list_opts)
-- 显示可用的命令
keyset("n", "<space>c", ":<C-u>CocList commands<cr>", list_opts)
-- 查找当前文档的符号大纲 (Outline)
keyset("n", "<space>o", ":<C-u>CocList outline<cr>", list_opts)
-- 在整个工作区搜索符号 (变量/函数名)
keyset("n", "<space>s", ":<C-u>CocList -I symbols<cr>", list_opts)
-- 对列表中的下一个项目执行默认操作
keyset("n", "<space>j", ":<C-u>CocNext<cr>", list_opts)
-- 对列表中的上一个项目执行默认操作
keyset("n", "<space>k", ":<C-u>CocPrev<cr>", list_opts)
-- 恢复并重新打开上一次的 coc list
keyset("n", "<space>p", ":<C-u>CocListResume<cr>", list_opts)


-- ==========================================
-- CoC插件
-- ==========================================
vim.g.coc_global_extensions = {
  'coc-symbol-line',
  'coc-python',
  'coc-pyright',
  'coc-clangd',
  'coc-json',
  'coc-marketplace',
  'coc-eslint',
  'coc-tsserver',
  'coc-sql',
  'coc-prettier',
  'coc-html',
  'coc-git',
  'coc-gitignore',
  'coc-css',
  'coc-yaml',
  'coc-syntax',
  'coc-snippets',
  'coc-explorer'
}


-- ==========================================
-- CoC插件 - coc-explorer
-- ==========================================
keyset('n', 'tt', ':CocCommand explorer<CR>', list_opts)
