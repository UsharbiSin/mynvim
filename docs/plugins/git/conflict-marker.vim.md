[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# conflict-marker.vim：合并冲突辅助

仓库：`rhysd/conflict-marker.vim`。两个系统均直接加载，没有本项目自定义映射。它识别
`<<<<<<<`、`=======`、`>>>>>>>` 等冲突区，提供高亮、文本对象和选择 ours/theirs/both/none
的操作。

发生冲突后先用 `:Git status` 确认文件，再在冲突区按 `:help conflict-marker` 查看锁定版本
的 `<Plug>` 映射；解决后仍需删除全部 marker、运行测试并 `git add`。插件不会自动判断哪一
侧正确，也不会替你完成 merge。若无高亮，检查 marker 是否完整以及 filetype。

上游：[conflict-marker.vim](https://github.com/rhysd/conflict-marker.vim)。
