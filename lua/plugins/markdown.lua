-- ==========================================
-- MarkdownPreview 配置
-- ==========================================
-- 设置为 1 可以在打开 markdown 文件的时候自动打开浏览器预览，只在打开markdown 文件的时候打开一次
vim.g.mkdp_auto_start = 0
-- 在切换 buffer 的时候自动关闭预览窗口，设置为 0 则在切换 buffer 的时候不自动关闭预览窗口
vim.g.mkdp_auto_close = 1
-- 设置为 1 则只有在保存文件，或退出插入模式的时候更新预览，默认为 0，实时更新预览
vim.g.mkdp_refresh_slow = 0
-- 设置为 1 则所有文件都可以使用 MarkdownPreview 进行预览，默认只有 markdown文件可以使用改命令
vim.g.mkdp_command_for_global = 0
-- 设置为 1, 在使用的网络中的其他计算机也能访问预览页面，默认只监听本地（127.0.0.1），其他计算机不能访问
vim.g.mkdp_open_to_the_word = 0
-- 使用自定义 IP 打开预览页面。
-- 当您在远程 Vim 中工作竝在本地浏览器上预览时非常有用
-- 更多详情请见: https://github.com/iamcco/markdown-preview.nvim/pull/9
-- 默认值为空
vim.g.mkdp_open_ip = ''
-- 指定要打开预览页面的浏览器
-- 对于包含空格了路径：
-- 有效: `/path/with\ space/xxx`
-- 无效: `/path/with\\ space/xxx`
vim.g.mkdp_browser = '/usr/lib/firefox/firefox'
-- 设置为 1 时，打开预览页面时会在命令行输出预览页面 URL，默认值为 0
vim.g.mkdp_echo_preview_url = 0
-- 用于打开预览页面的自定义 Vim 函数名，此函数将接收 URL 作为参数，默认值为空
vim.g.mkdp_browserfunc = ''

-- ==========Markdown渲染选项==========
-- mkit: markdown-it渲染选项
-- katex: KaTeX数学选项
-- uml： markdown-it-plantuml选项
-- maid: mermaid选项
-- disable_sync_scroll: 是否禁用同步滚动，默认值为0
-- sync_scroll_type: 'middle', 'top', 'relative'，默认值为'middle'
-- middle: 光标位置始终位于预览页面的中间
-- top: Vim顶部视口始终显示在预览页面的顶部
-- relative: 光标位置始终位于预览页面的相对位置
-- hide_yaml_meta: 是否隐藏YAML元数据，默认值为1
-- sequence_diagrams: js-sequence_diagrams选项
-- content_editable: 是否启用预览页面内容可编辑，默认值: false
-- disable_filename: 是否禁用预览页面的文件名标题，默认值: 0
vim.g.mkdp_preview_options = {
  mkit = {
    html = true,
    xhtmlOut = true,
    breaks = true,
    linkify = true,
    typographer = true
  },
  katex = {},
  uml = {},
  maid = {},
  disable_sync_scroll = 0,
  sync_scroll_type = 'middle',
  hide_yaml_meta = 1,
  sequence_diagrams = {},
  flowchart_diagrams = {},
  content_editable = false,
  disable_filename = 0,
  toc = {}
}

-- 使用自定义 Markdown 样式。必须是绝对路径。
vim.g.mkdp_markdown_css = '/home/usharbisin/.config/nvim/markdown.css'
-- 使用自定义高亮样式。必须是绝对路径
vim.g.mkdp_highlight_css = ''
-- 使用自定义端口启动服务器，或者留空以随机分配端口。
vim.g.mkdp_port = ''
-- 预览页面标题，${name} 将被替换为文件名
vim.g.mkdp_page_title = '「${name}」'
-- 使用自定义图片位置
vim.g.mkdp_images_path = '/home/usharbisin/vimwiki/.markdown_images'
-- 已识别的文件类型
-- 这些文件类型将具有 MarkdownPreview... 命令
vim.g.mkdp_filetypes = { 'markdown', 'vimwiki' }
-- 设置默认主题（深色或浅色）
vim.g.mkdp_theme = 'dark'
-- 合并预览窗口
-- 默认值: 0
-- 如果启用此选项，预览 Markdown 文件时将重用之前打开的预览窗口
-- 如果启用此选项，请确保设置 `let g:mkdp_auto_close = 0`
vim.g.mkdp_combine_preview = 0
-- 当 Markdown 缓冲区更改时自动重新获取合并预览内容
-- 仅当 `g:mkdp_combine_preview` 为 1 时可用
vim.g.mkdp_combine_preview_auto_refresh = 1

-- 预览模式开启/关闭快捷键
vim.keymap.set('n', '<F8>', '<Plug>MarkdownPreview', { silent = true })
vim.keymap.set('n', '<F9>', '<Plug>MarkdownPreviewStop', { silent = true })
vim.keymap.set('n', '<C-p>', '<Plug>MarkdownPreviewToggle', { silent = true })


-- ==========================================
-- img-paste.vim 剪贴板图片配置 (Wayland/Hyprland 适配)
-- ==========================================
-- 检测并为 Wayland (Hyprland) 环境配置 wl-paste
if vim.env.XDG_SESSION_TYPE == 'wayland' or vim.env.HYPRLAND_INSTANCE_SIGNATURE ~= nil then
  vim.g.mdip_imgdir_in_script = 'img'
  vim.g.CaptureClipboardImage = function(file_path)
    -- 使用 vim.fn.shellescape 处理路径转义
    local safe_path = vim.fn.shellescape(file_path)
    -- 拼接命令
    local cmd = 'wl-paste -t image/png > ' .. safe_path
    -- 使用 vim.fn.system 执行系统命令
    vim.fn.system(cmd)
    -- 使用 vim.v 获取 Vim 内置的执行状态码 (相当于 v:shell_error)
    return vim.v.shell_error
  end
end
vim.g.mdip_imgdir = '.markdown_images'
vim.g.mdip_imgname = 'image'
