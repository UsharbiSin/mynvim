[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vimwiki：个人知识库

仓库：`vimwiki/vimwiki`，启动时执行 [vimwiki.lua](../../../lua/config/vimwiki.lua)。默认 wiki
目录为 `~/vimwiki/`，语法 Markdown，扩展名 `.md`；表格自动格式化和 Vimwiki 表格映射关闭，
交给 vim-table-mode。

常用上游入口是 `<Space>ww` 打开默认 Wiki 索引、Enter 跟随/创建链接、Backspace 返回；本项目
没有改这些默认映射。先用 `:echo expand('~/vimwiki/')` 核对跨平台路径。普通 Markdown 文件
可能被 Vimwiki 改为 `vimwiki` filetype，配置已把它注册到 Markdown Tree-sitter，并显式让
预览、图片和渲染插件支持它。

上游：[Vimwiki](https://github.com/vimwiki/vimwiki)。
