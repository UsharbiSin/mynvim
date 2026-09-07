[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# lazy.nvim：插件管理器

仓库：`folke/lazy.nvim`。`init.lua` 在 `stdpath('data')/lazy/lazy.nvim` 不存在时，通过 Git 克隆
stable 分支，再调用 `require('lazy').setup('plugins')` 读取
[plugin-list.lua](../../../lua/plugins/plugin-list.lua)。

`:Lazy` 打开管理界面，`:Lazy sync` 安装缺失插件、更新并清理，`:Lazy log` 看下载/构建日志，
界面按 `?` 查看锁定版本的完整按键。`lazy-lock.json` 锁定插件提交，应随配置一起版本控制；
它不锁 Mason 工具、npm 构建产物或系统软件。首次引导失败先确认 `git` 与 GitHub 网络。

两个分支锁定的 lazy.nvim 提交不同，不要只复制锁文件。更新插件后若 Tree-sitter query 改变，
还要同步 parser。上游：[lazy.nvim](https://github.com/folke/lazy.nvim)。
