# WezTerm 行内图片实验

Windows 在检测到 `WEZTERM_PANE` 时，把 Markdown/Vimwiki 中的普通图片、LaTeX 数学公式和图表交给 image.nvim。配置使用 Kitty 普通定位及虚拟留白，以兼容 WezTerm 不支持 Unicode placeholders 的情况。Linux 不加载这套兼容层，文档图片和公式直接使用 Snacks 原生 inline。

Windows 的终端尺寸来自 `wezterm cli list --format json` 中当前 pane 的像素尺寸，避免调用 Unix ioctl。窗口缩放或重新获得焦点时会重新查询。请确保 `wezterm` 和 `magick` 都在 `PATH` 中。尺寸查询失败时可检查 `:messages`，并运行：

```vim
:lua vim.print(require('image/utils/term').get_size())
```

LaTeX 公式由 Snacks 负责解析和转换，转换结果再交给 image.nvim 定位。系统需要安装 `tectonic` 或 `pdflatex`。同一公式处于转换中时只允许存在一个任务；文档发生变化或关闭行内显示后，过期结果不会再发送给终端，避免大量 Kitty 数据阻塞 WezTerm。

diagram.nvim 负责生成 Mermaid、PlantUML、D2 和 Gnuplot 图片。Windows 使用同一套 image.nvim 行内定位；Mermaid 和 D2 使用 3 倍缩放，Mermaid 宽度为 2400 像素，Gnuplot 输出为 2400×1500。图表显示宽度根据当前窗口正文区域动态计算，目标为可用宽度的 90%，分屏后也会重新计算。配置还会把渲染尺寸版本写入图表缓存键，避免 diagram.nvim 继续复用调整尺寸前生成的小图。Linux 保持插件的原生图像后端。不同图表仍需安装相应的渲染命令。

按 `<leader>ilm` 可以同时切换普通图片、公式和流程图的行内显示，默认开启。Windows 切换 image.nvim，Linux 切换 Snacks inline。

验证时请重启 Neovim，打开包含图片、公式和流程图的 Markdown 文件，检查首次显示、连续刷新、上下滚动、分屏、窗口缩放、折叠，以及关闭和重新开启行内显示。可以用 `:ImageReport` 查看 Windows 图像后端状态。

WezTerm 的 Kitty 协议实现未获 image.nvim 官方支持，这仍是实验方案。首次转换和终端传输速度取决于外部渲染器、图片尺寸、磁盘速度及 WezTerm。
