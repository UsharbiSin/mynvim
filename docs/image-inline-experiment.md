# WezTerm 行内图片实验

Windows 在检测到 `WEZTERM_PANE` 时，把 Markdown/Vimwiki 中的普通图片、LaTeX 数学公式和图表交给 image.nvim。配置使用 Kitty 普通定位及虚拟留白，以兼容 WezTerm 不支持 Unicode placeholders 的情况。Linux 不加载这套兼容层，文档图片和公式直接使用 Snacks 原生 inline。

Windows 的终端尺寸来自 `wezterm cli list --format json` 中当前 pane 的像素尺寸，避免调用 Unix ioctl。窗口缩放或重新获得焦点时会重新查询。请确保 `wezterm` 和 `magick` 都在 `PATH` 中。尺寸查询失败时可检查 `:messages`，并运行：

```vim
:lua vim.print(require('image/utils/term').get_size())
```

LaTeX 公式由 Snacks 负责解析和转换，转换结果先经 ImageMagick 缩小到 1200×400 像素以内并移除透明通道，再交给 image.nvim 定位。系统需要安装 `tectonic` 或 `pdflatex`。Windows 打开文档时显示全部可见图片和公式；进入 Insert 模式后保留现有图片并暂停向终端发送新的渲染。返回 Normal 模式时检查文档是否发生变化，未修改则保持原图，修改后才作废旧公式并重新扫描图片路径，避免无意义的清除、重传和残影。Linux 仍使用 Snacks 完整 inline，不受此兼容层影响。

图片首次创建虚拟留白后，Windows 会先清除旧定位、刷新文本布局，再延迟一个短帧按新布局发送图片。这用于避免图片覆盖下方几行背景，以及必须手动滚动后才能恢复的问题。

diagram.nvim 负责生成 Mermaid、PlantUML、D2 和 Gnuplot 图片。Windows 使用同一套 image.nvim 行内定位；Mermaid 和 D2 使用 3 倍缩放，Mermaid 宽度为 2400 像素，Gnuplot 输出为 2400×1500。图表显示宽度根据当前窗口正文区域动态计算，目标为可用宽度的 90%，分屏后也会重新计算。配置还会把渲染尺寸版本写入图表缓存键，避免 diagram.nvim 继续复用调整尺寸前生成的小图。Linux 保持插件的原生图像后端。不同图表仍需安装相应的渲染命令。

按 `<leader>ilm` 可以同时切换普通图片、公式和流程图的行内显示，默认开启。Windows 切换 image.nvim，Linux 切换 Snacks inline。

为避免图片较多时阻塞 WezTerm，虚拟留白完成后的校正会按窗口合并，在 80 毫秒内只执行一次，并且只处理当前可见区域。每个窗口从最上方的可见图片开始一次级联重绘，不再为每张图片分别清除和重发 Kitty placement。进入插入模式后保留虚拟留白、暂停图片发送，退出插入模式后再统一恢复，从而避免编辑时文字布局反复变化造成错位。

验证时请重启 Neovim，打开包含较多图片、公式和流程图的 Markdown 文件，检查首次显示、快速滚动、连续编辑、分屏、窗口缩放、折叠，以及关闭和重新开启行内显示。可以用 `:ImageReport` 查看 Windows 图像后端状态。

WezTerm 的 Kitty 协议实现未获 image.nvim 官方支持，这仍是实验方案。首次转换和终端传输速度取决于外部渲染器、图片尺寸、磁盘速度及 WezTerm。
