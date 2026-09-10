[返回项目使用说明](../README.md) · [返回文档索引](README.md)

# Office 文档预览与轻度编辑

本配置把 Office 文件分成两个互补模式：Preview Mode 使用 Office 排版引擎生成 PDF，再把
PDF 页面显示在 Neovim 中；Edit Mode 读取 DOCX/XLSX 的 OOXML，只回写用户实际修改的文本
节点或单元格。轻度编辑并不等同于完整 Word/Excel 编辑。

| 格式 | Preview Mode | Edit Mode |
| --- | --- | --- |
| `.docx` | Word COM 或 LibreOffice 排版 | 正文、标题、列表和表格单元格文字 |
| `.xlsx` | Excel COM 或 LibreOffice 排版 | 普通单元格、日期、布尔值与公式 |
| `.pptx` | PowerPoint COM 或 LibreOffice 排版 | 不支持 |
| `.pdf` | 直接渲染页面 | 不支持 |

## 使用方式

直接打开 DOCX/XLSX 会进入结构化编辑缓冲区：

```vim
:edit report.docx
:edit report.xlsx
```

PPTX/PDF 会直接进入高保真预览。Office 缓冲区提供以下命令和快捷键：

| 命令 | 快捷键 | 功能 |
| --- | --- | --- |
| `:OfficePreview` | `<Space>op` | 预览磁盘中已保存文档的真实排版 |
| `:OfficeEdit` | `<Space>oe` | 进入或重新读取 DOCX/XLSX 轻度编辑缓冲区 |
| `:OfficeSave` | `<Space>os` | 安全保存当前 DOCX/XLSX |
| `:OfficeRefresh` | `<Space>or` | 清除当前文档预览缓存并重新转换 |
| `:OfficeHealth` | 无 | 运行 Office 依赖检查 |

XLSX 缓冲区使用 `csvview.nvim` 绘制表格边框并对齐列。该插件只负责显示和导航，不参与读取或
保存 XLSX；文件仍由 OOXML 模块按单元格最小回写。使用 `Tab` / `Shift-Tab` 切换单元格，
`]s` / `[s` 切换下一个/上一个 Sheet，按 `K` 查看当前单元格的
引用、类型、样式索引或公式。第一列是只读语义的行号，第二行是列名；只应修改数据区域。
单元格中的换行和 Tab 会显示为 `\n` 和 `\t`，保存时还原。

公式以 `=` 开头显示。修改公式单元格时必须保留 `=`；保存后会移除该单元格的旧缓存值，
由 Excel 或 LibreOffice 重新计算，绝不会把缓存值静默覆盖到公式上。日期以 ISO 格式显示，
例如 `2026-09-10`。共享公式、数组公式、数据表公式和富文本单元格会显示，但拒绝轻度编辑。
合并区域只允许修改左上角单元格。

## Preview Mode

转换和页面生成通过 `vim.system()` 异步执行，不阻塞 Neovim。预览窗口会立即打开并显示进度；
第一页生成后立即显示，其余页面继续在后台生成。处理链如下：

```text
DOCX / XLSX / PPTX -> Microsoft Office COM 或 LibreOffice -> PDF
PDF -> pdftoppm 或 mutool -> PNG 页面 -> image.nvim -> WezTerm
```

Windows 优先调用已安装的 Word、Excel 或 PowerPoint COM；COM 不可用或转换失败时自动尝试
LibreOffice。Arch Linux 使用 LibreOffice headless。PDF 页面复用现有 `image.nvim`，没有安装
重复的图片插件。

缓存位于 `stdpath('cache')/office-preview/`。缓存键由文件绝对路径、mtime 和大小组成；只有全部
页面成功生成后才将缓存标记为完整。源文件没有变化时直接复用页面。默认以 120 DPI 生成页面，
可以通过 `vim.g.office_preview_dpi` 调整。`:OfficeRefresh` 强制刷新当前文档。预览展示的是磁盘版本，因此应先
保存 Edit Mode 中的修改。

## Edit Mode 与文件安全

DOCX 编辑缓冲区用类似 Markdown 的虚拟标题、列表符号和表格标记呈现结构；这些标记不会写入
文档。DOCX 以文档 XML 中的段落索引和文本节点顺序建立稳定映射，不依赖全文搜索。一个可见词语即使
被拆成多个 `<w:r>/<w:t>`，保存时仍会按照原节点边界分配修改，保留对应 `<w:rPr>` 中的字体、
字号、粗体和斜体等属性。相同文本出现在多处时也会按段落 ID 定点修改。

XLSX 读取 workbook relationship、Sheet 和 cell 引用。共享字符串修改为目标 cell 自己的
inline string，避免连带改变引用同一 shared string 的其他单元格。工作表 XML 之外的样式、
drawing、chart、条件格式、数据验证和其他 Sheet 不会重建。

每次保存遵循以下步骤：

1. 检查文件 SHA-256 指纹，拒绝覆盖打开后被其他程序修改的文件；
2. 在原文件目录写临时 ZIP；
3. 检查 ZIP、`[Content_Types].xml`、`_rels`、主 XML 和所有修改 XML；
4. 首次成功修改前创建 `文件名.office-backup`，后续保存不产生无限备份；
5. 验证成功后用原子替换更新原文件，失败时删除临时文件并保留原文件。

## 外部依赖

两个系统都需要 Python 3 进行 OOXML 解析，需要 WezTerm 和现有 `image.nvim` 图像依赖显示
页面。执行 `:checkhealth office` 查看实际探测结果。

Windows 11：

- Microsoft Office 是首选渲染器，但不是强制依赖；Word、Excel、PowerPoint 按实际格式使用；
- 没有 Microsoft Office 时安装 LibreOffice，并确保 `soffice` 或 `libreoffice` 在 `PATH`；
- 安装 Poppler 的 `pdftoppm`，也可使用 MuPDF 的 `mutool`；
- Python、PDF 渲染器、ImageMagick 和 WezTerm 都应在 `PATH`。

Arch Linux 可安装：

```bash
sudo pacman -S --needed python libreoffice-fresh poppler imagemagick wezterm
```

使用 `libreoffice-still` 时可替换 `libreoffice-fresh`，不要同时安装两者。

## 当前限制

- DOCX 只修改已有段落文字，不能新增或删除段落；图片、文本框、SmartArt、公式、批注、修订、
  域和复杂页眉页脚不提供编辑入口。含域、修订、文本框、换行或 Tab 的段落会警告并拒绝修改。
- XLSX 第一版展示每个 Sheet 最多前 1000 行和 52 列；不编辑 chart、image、pivot table、
  drawing、条件格式规则或数据验证规则，但保存会保留这些 ZIP 条目。
- 创建空白单元格支持字符串和以 `=` 开头的公式；现有数字、布尔值和日期必须保持原类型。
- DOCX/XLSX 的排版只能在 Preview Mode 查看，Edit Mode 是接近 Markdown/表格的结构视图。
- 首次 Preview 仍需启动 Office 或 LibreOffice 并导出 PDF，速度取决于文档复杂度和外部程序；
  第一页会优先显示，后续打开相同且未修改的文件直接使用缓存。
- WezTerm 图像协议的显示质量和滚动行为仍受当前 Windows `image.nvim` 兼容层限制。

## 排错

先执行：

```vim
:checkhealth office
:checkhealth image
:messages
```

Windows 首次调用 Office COM 若出现对话框或超时，先单独启动对应 Office 应用完成首次启动，
关闭文件占用后重试。LibreOffice 找不到时检查 `soffice --version`；PDF 页面不生成时检查
`pdftoppm -v` 或 `mutool -v`。保存被拒绝并提示文件已被其他程序修改时，用 `:OfficeEdit`
重新读取，不要覆盖外部版本。
