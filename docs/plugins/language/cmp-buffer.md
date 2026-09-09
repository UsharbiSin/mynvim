[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# cmp-buffer：当前文件中的单词补全

**仓库：** `hrsh7th/cmp-buffer`。作为 nvim-cmp 依赖自动安装和加载；配置见 [nvim-cmp.lua](../../../lua/config/nvim-cmp.lua)，源名 `buffer`。

## 当前作用

对当前缓冲区已有文本建立单词候选，不要求语言服务器或联网，适合重复输入函数名、配置项和文档中的英文术语。本项目没有指定 `get_bufnrs`，保留上游默认“当前缓冲区”；不会默认遍历项目全部文件。

本地锁定版本默认自动触发阈值为 3 个字符，候选按插件的单词正则提取。它不理解变量作用域，也不是中文语义补全。[上游源选项](https://github.com/hrsh7th/cmp-buffer#configuration)

## 操作示例

先在文本文件写一行 `project_documentation`，换行输入 `pro`，等待菜单或按 Ctrl-Space，用 Tab 选中候选后回车。菜单按键见 [nvim-cmp](nvim-cmp.md)，无插件专用映射。

## 可选调整与排错

若想从所有已打开 buffer 收集词，可在该源的 `option.get_bufnrs` 中返回 `vim.api.nvim_list_bufs()`；这是扩展示意，本仓库没有启用。大文件很多时扩大范围会增加扫描量。

候选不出现时执行 `:CmpStatus`，检查当前文本中确有完整单词并尝试较长前缀。LSP 关闭后仍出现词补全是本插件正常行为。main 在两个系统使用相同配置且无额外系统依赖；Windows 实机已确认配置加载。
