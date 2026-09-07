[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# indentpython.vim：Python 缩进规则

仓库：`vim-scripts/indentpython.vim`，仅 Python 文件加载，提供传统 Vim indent 脚本。
核心 [options.lua](../../../lua/core/options.lua)另把 Python tabstop、shiftwidth、softtabstop
设为 4 并 expandtab，符合常见 PEP 8 缩进。

但全局配置又设置 `indentexpr=''`，这可能清空 filetype indent 表达式并削弱本插件效果；
实际打开 Python 后运行 `:setlocal indentexpr? autoindent? smartindent?` 检查。格式化代码块
更适合使用 Black/Conform，而不是依赖自动缩进修复已有代码。

上游：[indentpython.vim](https://github.com/vim-scripts/indentpython.vim)。
