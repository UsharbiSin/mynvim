[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# vim-textobj-user：自定义文本对象框架

仓库：`kana/vim-textobj-user`。它为其他 Vimscript 插件定义 `a?` / `i?` 文本对象提供框架，
main 在两个系统都将其作为底层条目安装。

本项目没有直接调用其 API，也不单独注册用户按键；实际文本对象来自依赖它的插件。若某个
文本对象报 `textobj#user#plugin` 不存在，先在 `:Lazy` 检查此依赖。无需单独 setup。

上游：[vim-textobj-user](https://github.com/kana/vim-textobj-user)。
