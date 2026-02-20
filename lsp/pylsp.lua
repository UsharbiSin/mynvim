---@brief
---
--- https://github.com/python-lsp/python-lsp-server
---
--- A Python 3.6+ implementation of the Language Server Protocol.
---
--- See the [project's README](https://github.com/python-lsp/python-lsp-server) for installation instructions.
---
--- Configuration options are documented [here](https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md).
--- In order to configure an option, it must be translated to a nested Lua table and included in the `settings` argument.

---@type vim.lsp.Config
return {
  cmd = { 'pylsp' },
  filetypes = { 'python' },
  root_markers = {
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'Pipfile',
    '.git',
  },

  -- 严格按照官方文档的嵌套层级配置 pylsp 的内置插件
  settings = {
    pylsp = {
      plugins = {
        -- 补全与跳转 (由 Jedi 引擎提供支持)
        jedi_completion = {
          enabled = true,
          include_params = true -- 补全时包含函数参数
        },
        jedi_hover = { enabled = true },
        jedi_references = { enabled = true },
        jedi_signature_help = { enabled = true },

        -- 导入排序 (替代旧配置中的相关功能)
        isort = { enabled = true },

        -- 代码规范与类型检查 (完美替代原 coc-settings.json 中的 diagnosticSeverityOverrides)
        pycodestyle = { enabled = false }, -- 关闭默认较弱的检查器
        flake8 = {
          enabled = true,
          -- 你可以在这里按需添加 ignore = {'W391'} 等规则
        },
        mypy = {
          enabled = true,
          live_mode = true, -- 开启实时类型检查
          strict = false,   -- 可按需开启严格模式
        },
      }
    }
  }
}
