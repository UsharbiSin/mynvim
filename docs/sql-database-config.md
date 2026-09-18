[返回项目使用说明](../README.md) · [SQLS 插件说明](plugins/language/sqls.nvim.md)

# Windows / Arch Linux SQL 数据库配置

两个系统使用同一份 `main` 配置。普通连接参数从环境变量读取，密码只从本机系统凭据库按需
获取：Windows 使用凭据管理器，Arch 使用 Secret Service（例如 GNOME Keyring）。不把密码
放进 Git，不自动同步两台机器的凭据，不回退到 `.env` 或旧密码环境变量。

## 1. 普通连接参数

每个连接必须有 `DB_USER_*`、`DB_HOST_*`、`DB_PORT_*`、`DB_NAME_*` 四项非空参数。
密码不再是环境变量中的必填项。连接定义集中在
[`sql-credentials.lua`](../lua/config/sql-credentials.lua)。

| 连接名称 / 凭据名称 | 参数后缀 | Windows 凭据目标 |
| --- | --- | --- |
| `tongyan` | `TY` | `nvim/sql/tongyan` |
| `tongyan_test` | `TYTEST` | `nvim/sql/tongyan_test` |
| `platform_st` | `ST` | `nvim/sql/platform_st` |
| `platform_st_test` | `STTEST` | `nvim/sql/platform_st_test` |

Windows 在启动 Neovim 的 PowerShell 中设置普通参数：

```powershell
$env:DB_USER_ST = 'query_user'
$env:DB_HOST_ST = '127.0.0.1'
$env:DB_PORT_ST = '3306'
$env:DB_NAME_ST = 'database'
```

Arch 在启动 Neovim 的 shell 中设置：

```bash
export DB_USER_ST='query_user'
export DB_HOST_ST='127.0.0.1'
export DB_PORT_ST='3306'
export DB_NAME_ST='database'
```

普通参数也可保存到各自的用户环境配置。修改后重新启动终端和 Neovim；连接名称必须与
系统凭据中的名称一致。普通参数不完整时，连接不显示；密码缺失时连接仍显示，但连接操作
会明确失败，不使用其他默认密码尝试连接。

## 2. Windows：保存或迁移密码

安装可从 `PATH` 找到的 Python 3.10 或更新版本；助手只使用标准库，不需要安装 pip 包。
在配置仓库根目录的交互终端执行：

```powershell
python -I -S -B -X utf8 scripts/sql_credentials.py set platform_st
python -I -S -B -X utf8 scripts/sql_credentials.py set platform_st_test
```

按提示输入并确认密码；密码不会显示，也不进入命令历史。凭据属于当前登录用户，保存到
当前计算机的 Windows 凭据管理器。不要使用 `cmdkey /pass:真实密码` 或把密码作为脚本参数。

已有 Windows 用户环境变量时，可以直接迁移，不需要重新输入密码：

```powershell
python -I -S -B -X utf8 scripts/sql_credentials.py migrate
```

迁移会读取 `HKCU\Environment` 中的旧变量（缺失时再检查调用进程环境），逐项写入并回读
校验，只显示状态。已有不同值的凭据不会被静默覆盖；需要修改时明确使用 `set`。
默认保留旧环境变量，避免破坏其他依赖它们的项目。Neovim 自身已经不再使用这些旧变量。

确认其他程序不再依赖旧变量，且 SQLS / Grip 均连接正常后，才可显式删除 Windows 用户变量：

```powershell
python -I -S -B -X utf8 scripts/sql_credentials.py migrate --remove-env
```

脚本只有在所有尝试迁移的凭据均回读成功后才删除旧用户变量，不修改机器级环境变量。
现有进程持有的环境副本不会被远程清除，建议注销后重新登录。没有删除的系统旧变量仍是
明文暴露面，不能把“已迁入凭据库”理解为“旧副本已消失”。

## 3. Arch：Secret Service 钥匙环

已有兼容 Secret Service 的钥匙环时可以继续使用，不要同时启动多个争用该服务名的后端。
没有时可安装：

```bash
sudo pacman -S --needed gnome-keyring libsecret seahorse
```

在 Seahorse 中创建并解锁有密码保护的默认钥匙环。不要为了自动解锁设置空钥匙环密码。
Hyprland 不负责代替钥匙环服务：先验证图形会话中的 D-Bus 和手动解锁，再按实际登录方式
设置 PAM 自动解锁。不要把某一套 `/etc/pam.d/*` 配置无条件复制到所有登录管理器。

若图形会话尚未导入所需的激活环境，可在会话启动流程中执行：

```bash
dbus-update-activation-environment --systemd \
  DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP
```

只导入所需变量，不使用 `--all` 传播整份环境。按提示交互保存密码：

```bash
secret-tool store --label='Neovim SQL / platform_st' \
  application nvim-sql connection platform_st
secret-tool store --label='Neovim SQL / platform_st_test' \
  application nvim-sql connection platform_st_test
```

也可在配置仓库根目录运行 `python3 scripts/sql_credentials.py set platform_st`。
不要用 `echo '真实密码' | ...`，不要把真实密码写进命令参数。

已有 shell 密码环境变量时，可在仍持有这些变量的独立交互终端运行：

```bash
cd ~/.config/nvim
python3 scripts/sql_credentials.py migrate
```

Linux 迁移会逐项询问确认。成功后手动移除 `.bashrc`、`.zshrc`、环境配置文件等位置的旧
`DB_PASSWORD_*` 定义，并重建登录会话；脚本不能修改父 shell 环境。不要在 Neovim 内部的
终端迁移旧密码：Neovim 启动时已清理这些变量，新建子终端不会再继承它们。

客户端兼容设置独立保留：非 Windows 平台检测到
`~/.local/lib/mysql/plugin/mysql_native_password.so` 时，受管理的 Grip 连接自动传入对应的
`--plugin-dir`。自定义路径可以设置 `DB_MYSQL_PLUGIN_DIR`；一个路径作为一个 argv 参数传递。
这只影响 `mysql` CLI，不影响使用 Go 驱动的 SQLS。

## 4. 检查与重新加载

```vim
:SqlCredentialsCheck
:SqlCredentialsCheck platform_st
:SqlCredentialsReload
```

`Check` 只显示凭据是否可用，不显示密码，也不连接数据库。读取可能弹出系统解锁提示，
每次取密超时为 60 秒；缺少服务、取消解锁或凭据不存在都会报告失败。没有长期密码缓存。
`Reload` 给已运行的 SQLS 重新发送配置；Grip 会在下一次查询时重新读取密码。

进入 SQL 缓冲区后检查语言服务器：

```vim
:MasonInstall sqls
:checkhealth vim.lsp
:SqlsShowConnections
```

SQLS 初始化后异步取密，因此刚附着时连接列表可能尚未加载，并可能暂时提示
`no database connection`。凭据加载后可执行 `:SqlsShowConnections` 确认；持续失败时检查
钥匙环与实际网络，不要忽略错误。选择连接后用 `SELECT 1;`
做无副作用验证。不要打印整个 LSP 客户端、连接 DSN 或凭据助手 `get` 的输出排错。

## 5. 原有查询操作

| 按键 / 命令 | 行为 |
| --- | --- |
| `空格 sc` | 为当前 SQL 文件选择连接 |
| `空格 sr` | 执行当前文件或选中行；保持原始查询，不额外包裹 LIMIT |
| `空格 st` | 打开表与中文注释侧栏；点击表查询前 1000 行 |
| `空格 sg` / `:GripConnect` | 打开 Grip 数据库工作区 |
| `空格 swc` / `:SqlsSwitchConnection` | 切换 SQLS 连接 |
| `空格 swd` / `:SqlsSwitchDatabase` | 切换 SQLS 数据库 |
| `空格 ssc` / `:SqlsShowConnections` | 显示 SQLS 连接 |
| `空格 ssd` / `:SqlsShowDatabases` | 显示数据库列表 |
| `空格 sst` / `:SqlsShowTables` | 显示表列表 |
| `空格 se` / `:SqlsExecuteQuery` | 通过 SQLS 执行整个缓冲区或选中行 |
| `空格 sv` / `:SqlsExecuteQueryVertical` | SQLS 纵向结果 |

表侧栏中的 `l` / `h` 展开或收起列，`/` 筛选表名或注释，`F` 清除筛选，`K` 查看注释，
`r` 刷新元数据。Grip 结果中的 `Ctrl-h` / `Ctrl-l` 移动列，`Ctrl-s` / `Ctrl-d` 本地排序，
`/` 设置当前列筛选，`|` 切换筛选 AND/OR。排序不重新查询；筛选需要重新查询。
原有 CSV/XLSX 导出、结果下方 SQL 显示与复制不变。

## 6. 实现与安全边界

- `init.lua` 在加载插件前删除 Neovim 进程继承的 `DB_PASSWORD_*`、`MYSQL_PWD`，不修改父进程。
- [`sql-credentials.lua`](../lua/config/sql-credentials.lua) 管理别名、非敏感参数、取密和状态命令。
  两个平台后端在 [`sql-credentials/`](../lua/config/sql-credentials) 下。
- Grip 持久化旧 `${DB_PASSWORD_*}` 模板，运行时 URL 只含公开凭据标识；启动 MySQL 前检查
  标识对应的主机、端口和用户，仅向目标子进程设置 `MYSQL_PWD`，不把密码放入 argv。
- SQLS 用异步 `workspace/didChangeConfiguration` 获取内存 DSN；不将真实 DSN 放回共享
  `settings` 或 buffer。敏感通知的同步发送期间临时关闭 LSP RPC 日志，然后恢复原级别。
- 该兼容方案仍使用 MySQL 子进程的 `MYSQL_PWD`，不是“运行期间无明文”。MySQL 官方不建议
  使用该变量；完全取消它需要进一步更换 CLI 认证传递方式。SQLS 的进程内存也仍持有凭据。
- 系统凭据库不能隔离拥有同一用户任意代码执行权限的插件、代理或恶意程序；Lua/Python
  字符串也不能保证从进程内存中物理擦除。本方案主要减少长期明文存储和意外传播。
- 现有 TLS 和数据库授权策略不在本次迁移中改动，仍应单独核实证书验证和账号最小权限。
  查询历史、业务数据导出、服务器或第三方插件自身的日志需要另外保护。

## 7. 测试与验证范围

```text
python -B tests/sql_credentials.py
nvim --headless -u NONE -l tests/sql-credentials.lua
```

Python 测试在 Windows 会创建随机名称的测试凭据，验证真实读写后删除。Lua 测试使用虚构
密码检查两个后端、特殊字符、缺失凭据、无环境回退、目标绑定、同步/异步查询和 SQLS 日志
保护，不访问真实数据库。Arch 分支通过模拟测试不等于 Hyprland / D-Bus 实机已经验证。

本次 Windows 已完成两组凭据的回读、MySQL `SELECT 1`、SQLS 运行时配置和数据库列表
查询验证。可用 `NVIM_SQL_CREDENTIAL_LIVE=1` 显式启用
`tests/sql-credentials-live.lua` 复查；默认跳过真实数据库测试。

参考：[Windows CredWrite](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credwritew)、
[Secret Service API](https://gnome.pages.gitlab.gnome.org/libsecret/libsecret-simple-api.html)、
[Arch GNOME Keyring](https://wiki.archlinux.org/title/GNOME/Keyring)、
[MySQL 环境变量](https://dev.mysql.com/doc/refman/8.0/en/environment-variables.html)。
