[返回插件索引](../../README.md)

# csvview.nvim

上游项目：[hat0uma/csvview.nvim](https://github.com/hat0uma/csvview.nvim)

本项目仅在 `office-xlsx` 轻度编辑缓冲区中加载该插件，用虚拟文本绘制表格边框、对齐列，
并提供单元格导航。`Tab` 和 `Shift-Tab` 横向切换单元格，`Enter` 移到下一行；首列行号固定显示。

插件不会读取、转换或保存 `.xlsx`。工作簿仍由内置 Office OOXML 模块读取，并且只回写实际
修改过的单元格，因此不会采用 XLSX → CSV → XLSX 的破坏性转换流程。
