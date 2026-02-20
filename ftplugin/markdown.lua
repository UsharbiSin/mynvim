local map = vim.keymap.set
-- 只在 Markdown 中生效
local opts = { buffer = true, silent = true }

-- 插入模式下的标记补全
map('i', ',f', '<Esc>/<++><CR>:nohlsearch<CR>c4l', opts)
map('i', ',n', '---<Enter><Enter>', opts)
map('i', ',b', '**** <++><Esc>F*hi', opts)
map('i', ',s', '~~~~ <++><Esc>F~hi', opts)
map('i', ',i', '** <++><Esc>F*i', opts)
map('i', ',d', '`` <++><Esc>F`i', opts)
map('i', ',c', '``` <Enter><++><Enter>```<Enter><Enter><++><Esc>4kA', opts)
map('i', ',h', '<mark></mark> <++><Esc>F/hi', opts)
map('i', ',p', '![](<++>) <++><Esc>F[a', opts)
map('i', ',a', '[](<++>) <++><Esc>F[a', opts)
map('i', ',1', '# <Enter><++><Esc>kA', opts)
map('i', ',2', '## <Enter><++><Esc>kA', opts)
map('i', ',3', '### <Enter><++><Esc>kA', opts)
map('i', ',4', '#### <Enter><++><Esc>kA', opts)
map('i', ',l', '--------<Enter>', opts)
map('i', ',r', '<a style="color: red;"></a> <++><Esc>F/hi', opts)
map('i', ',t', '<a style="color: blue;"></a> <++><Esc>F/hi', opts)
