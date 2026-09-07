[返回项目使用说明](../../../README.md) · [返回插件分类索引](../../README.md)

# nvim-cmp：插入模式补全菜单

**仓库：** `hrsh7th/nvim-cmp`。启动时加载，配置见 [nvim-cmp.lua](../../../lua/config/nvim-cmp.lua)。

## 当前配置

补全来源依次声明为 [LSP](cmp-nvim-lsp.md)、[当前缓冲区单词](cmp-buffer.md)、[文件路径](cmp-path.md)。配置为 `menu,menuone,noselect`，回车确认使用 `select=false`，因此应先选择候选，再按回车。引擎可能受服务器返回结果及上游预选设置影响，不要把“回车不自动选第一项”理解成绝对禁止所有预选。

| 插入模式按键 | 本项目动作 |
| --- | --- |
| `Ctrl-Space` | 手动触发补全 |
| `Tab` / `Shift-Tab` | 下一项 / 上一项 |
| `Enter` | 确认已选候选 |
| `Ctrl-b` / `Ctrl-f` | 补全文档上翻 / 下翻 4 行 |

未弹菜单时 Tab 的回退行为由 cmp 映射实现决定；遇到缩进冲突以 `:verbose imap <Tab>` 为准。本项目未添加“Tab 在 snippet 占位符间跳转”的逻辑。

## 首次使用

打开 Lua 或 Python 文件，在对象后的 `.` 处输入前缀，或按 `Ctrl-Space`，再用 Tab/回车选择。即使 LSP 不运行，当前文件中已出现的单词仍可经 buffer 源补全；这不能证明语言服务正常。

项目 **没有配置 snippet.expand、LuaSnip、cmp-cmdline 或 cmp-nvim-lua**。因此不要把上游示例中的代码片段、命令行补全当成本项目现成能力。lspkind 只被 require，未接入菜单 formatter，默认图标效果也不应保证。

## 检查与排错

```vim
:CmpStatus
:lua vim.print(require("cmp").get_config().sources)
:verbose imap <CR>
:verbose imap <Tab>
```

若只缺 LSP 项，查看 [LSP 文档](nvim-lspconfig.md)；如果路径项不出现，检查当前输入是否包含 `./` 等路径前缀。Markdown 的 bullets、table-mode、Vimwiki 也会映射回车，按当前缓冲区的 `:verbose imap <CR>` 确认最终生效者。

两个分支配置一致。Windows Terminal/输入法可能截获 Ctrl-Space，可先用菜单自动触发验证。Windows 11 未实机测试。[上游手册](https://github.com/hrsh7th/nvim-cmp/blob/main/doc/cmp.txt)
