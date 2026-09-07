[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# mathjax-support-for-mkdp：旧版预览数学扩展

仓库：`iamcco/mathjax-support-for-mkdp`，Markdown/Vimwiki 加载。上游说明面向旧
`markdown-preview.vim` 方案；本项目安装的是 `markdown-preview.nvim`，后者自身已有 KaTeX
支持。因此不能保证这项扩展在当前组合中产生额外效果。

浏览器数学公式应先测试 markdown-preview.nvim 自带的 `$...$`/`$$...$$` 渲染；编辑器内
公式预览则由 Snacks 完成。遇到冲突时可先禁用此 spec，确认内置 KaTeX 是否已经满足需求。
它没有本项目快捷键和 setup。

上游：[mathjax-support-for-mkdp](https://github.com/iamcco/mathjax-support-for-mkdp)。
