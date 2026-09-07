[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# lspkind.nvim：补全类型图标库

**仓库：** `onsails/lspkind.nvim`。作为 nvim-cmp 依赖安装；[nvim-cmp.lua](../../../lua/config/nvim-cmp.lua) 只执行了 `require("lspkind")`。

## 已安装与未接入的部分

上游可把 Function、Variable、Class 等补全种类转换成图标或图标加文字，方便识别候选类型。但当前 cmp 配置 **没有** 设置 `formatting.format = lspkind.cmp_format(...)`，也没有调用 `lspkind.init()`。因此本仓库不能保证菜单显示该插件图标；单纯安装并 require 并不等于完成图标格式化。

## 需要图标时的可选配置

以下片段可合并到现有 `cmp.setup` 表中，当前仓库未开启：

```lua
formatting = {
  format = require("lspkind").cmp_format({
    mode = "symbol_text",
  }),
},
```

同时在终端选择支持相应字形的 Nerd Font。配置后用函数和变量候选对照检查图标。无需额外程序，不改变 LSP 分析能力，也没有独立快捷键。[上游 cmp 接入说明](https://github.com/onsails/lspkind.nvim#option-2-nvim-cmp)

两分支一致，Windows 11 未实机测试。出现方框先查终端字体；完全没有图标先查是否真的接入了 formatter，而非先重装 LSP。
