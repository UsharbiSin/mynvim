[返回项目使用说明](../../../README.md) · [返回插件索引](../../README.md)

# LspProxy：LSP 文档中文翻译

仓库：`SantaChains/LspProxy`。它是语言服务器前置代理，不是 Neovim 界面插件。配置检测到
`LspProxy` 可执行文件后，会自动代理 pylsp、clangd、lua_ls、html、jsonls 和 sqls；找不到时
直接使用原语言服务器。

代理会翻译 LSP Hover、补全文档、签名说明和诊断消息。普通模式按 `K` 时，Python、C/C++
等语言服务器返回的英文 docstring 或说明会显示为中文，代码块、函数签名、标识符和类型名
保持原样。这里翻译的是语言服务器提供的内容，并不会跳转到语言官方网站。

默认使用无需密钥的 Google 与 MyMemory 在线翻译，内容需要发送到翻译服务。首次遇到长文档
可能因默认 600 毫秒超时先显示英文，后台翻译完成后再次按 `K` 即可命中磁盘缓存。免费服务
若返回 429/403，代理会保留英文；可用 `LspProxy --tui` 改用 OpenAI、DeepSeek 或本地 Ollama
等兼容接口。

Windows 和 Arch Linux 都需要 Go 1.25 或更高版本：

```powershell
winget install --id GoLang.Go -e
go install github.com/SantaChains/LspProxy@latest
LspProxy --version
```

```bash
sudo pacman -S --needed go
go install github.com/SantaChains/LspProxy@latest
LspProxy --version
```

确保 `$(go env GOPATH)/bin` 在 PATH 中，然后重启 Neovim。配置文件首次运行时自动创建，
可执行 `LspProxy --tui` 调整翻译引擎、超时、显示模式和术语表。

上游：[LspProxy](https://github.com/SantaChains/LspProxy)。
