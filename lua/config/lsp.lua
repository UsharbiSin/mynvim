-- 唤醒 nvim-lspconfig，它会自动把所有已知语言的默认配置注册到底层 vim.lsp.config 中
-- require("lazydev").setup({})
require("lspconfig")

local translate = require("config.lsp-translate")
local clangd_command = { "clangd" }
local query_drivers = {}
local clangd_fallback_flags = {}
for _, compiler in ipairs({ "gcc", "g++", "clang", "clang++" }) do
  local path = vim.fn.exepath(compiler)
  if path ~= "" then query_drivers[#query_drivers + 1] = vim.fs.normalize(path) end
end
if #query_drivers > 0 then
  clangd_command[#clangd_command + 1] = "--query-driver=" .. table.concat(query_drivers, ",")
end

local gcc = vim.fn.exepath("gcc")
if gcc ~= "" then
  local target = vim.system({ gcc, "-dumpmachine" }, { text = true }):wait(3000)
  if target.code == 0 and vim.trim(target.stdout or "") ~= "" then
    clangd_fallback_flags[#clangd_fallback_flags + 1] = "--target=" .. vim.trim(target.stdout)
  end
  local includes = vim.system({ gcc, "-E", "-x", "c++", "-", "-v" }, {
    text = true,
    stdin = "",
  }):wait(5000)
  local collecting = false
  for line in ((includes.stderr or "") .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    if line:find("#include <...> search starts here:", 1, true) then
      collecting = true
    elseif collecting and line:find("End of search list.", 1, true) then
      break
    elseif collecting then
      local path = vim.trim(line:gsub(" %(framework directory%)$", ""))
      if path ~= "" then
        clangd_fallback_flags[#clangd_fallback_flags + 1] = "-isystem"
        clangd_fallback_flags[#clangd_fallback_flags + 1] = vim.fs.normalize(path)
      end
    end
  end
end

for name, command in pairs({
  clangd = clangd_command,
  html = { "vscode-html-language-server", "--stdio" },
  jdtls = { "jdtls" },
  jsonls = { "vscode-json-language-server", "--stdio" },
  lua_ls = { "lua-language-server" },
  pylsp = { "pylsp" },
  sqls = { "sqls" },
  ts_ls = { "typescript-language-server", "--stdio" },
}) do
  local config = { cmd = translate.command(command) }
  if name == "clangd" and #clangd_fallback_flags > 0 then
    config.init_options = { fallbackFlags = clangd_fallback_flags }
  end
  vim.lsp.config(name, config)
end

-- 两个平台共用同一套诊断展示；LSP 附着前也保持一致。
vim.diagnostic.config({
  virtual_text = true,
  virtual_lines = false,
  signs = true,
  underline = true,
  update_in_insert = false,
  float = { source = true, border = "rounded" },
})

-- ==========================================
-- 修改特定 Server 的配置
-- ==========================================
if vim.lsp.config.pylsp then
  vim.lsp.config.pylsp.settings = {
    pylsp = {
      plugins = {
        jedi_completion = { enabled = true, include_params = true },
        jedi_hover = { enabled = true },
        jedi_references = { enabled = true },
        jedi_signature_help = { enabled = true },
        isort = { enabled = true },                  -- 导入排序
        pycodestyle = { enabled = false },           -- 禁用基础检查
        flake8 = { enabled = true },                 -- 启用 Flake8 检查
        mypy = { enabled = true, live_mode = true }, -- 启用 Mypy 类型检查
      },
    },
  }
end

-- ==========================================
-- 启用 LSP Servers
-- ==========================================
-- 遍历你想启动的服务器，使用原生 enable 命令启动
vim.lsp.enable("clangd")
vim.lsp.enable("html")
vim.lsp.enable("jsonls")
vim.lsp.enable("lua_ls")
vim.lsp.enable("pylsp")
vim.lsp.enable("sqls")
vim.lsp.enable("ts_ls")

local java = vim.fn.exepath("java")
if java ~= "" then
  local version = vim.system({ java, "-version" }, { text = true }):wait(3000)
  local output = (version.stdout or "") .. (version.stderr or "")
  local major = tonumber(output:match('version "1%.(%d+)')) or tonumber(output:match('version "(%d+)'))
  if major and major >= 21 then vim.lsp.enable("jdtls") end
end

local function format_with_lsp(bufnr, range)
  if vim.tbl_contains({ "sql", "mysql" }, vim.bo[bufnr].filetype) then
    local conform_range
    if range then
      local first = vim.fn.getpos("'<")
      local last = vim.fn.getpos("'>")
      local end_line = vim.api.nvim_buf_get_lines(bufnr, last[2] - 1, last[2], true)[1] or ""
      conform_range = {
        start = { first[2], first[3] - 1 },
        ["end"] = { last[2], #end_line },
      }
    end
    require("conform").format({
      bufnr = bufnr,
      async = true,
      lsp_format = "never",
      range = conform_range,
    })
    return
  end

  local method = range
      and vim.lsp.protocol.Methods.textDocument_rangeFormatting
      or vim.lsp.protocol.Methods.textDocument_formatting
  local supported = false

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method(method, { bufnr = bufnr }) then
      supported = true
      break
    end
  end

  if not supported then
    local target = range and "选中范围" or "当前文件"
    vim.notify(target .. "没有支持格式化的 LSP", vim.log.levels.WARN, { title = "LSP" })
    return
  end

  vim.lsp.buf.format({
    bufnr = bufnr,
    async = false,
    filter = function(client)
      return client:supports_method(method, { bufnr = bufnr })
    end,
  })
end


-- ==========================================
-- LspAttach 回调：统一设置快捷键与 UI 逻辑
-- ==========================================
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("SetupLSP", {}),
  callback = function(event)
    local client = assert(vim.lsp.get_client_by_id(event.data.client_id))

    if client.name == "sqls" then
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end

    -- 开启 LSP 语义高亮 (Semantic Tokens)
    if client.server_capabilities.semanticTokensProvider and vim.lsp.semantic_tokens.enable then
      vim.lsp.semantic_tokens.enable(true, { bufnr = event.buf, client_id = client.id })
    end

    local function map(mode, keys, func, desc)
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP：" .. desc })
    end

    -- [Keymaps] 快捷键映射
    map("n", "gd", vim.lsp.buf.definition, "跳转到定义")
    map("n", "gr", vim.lsp.buf.references, "查看引用")
    map("n", "gi", vim.lsp.buf.implementation, "跳转到实现")
    map("n", "gy", vim.lsp.buf.type_definition, "跳转到类型定义")
    map("n", "K", vim.lsp.buf.hover, "查看悬浮文档")
    map("n", "<leader>rn", vim.lsp.buf.rename, "重命名符号")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "执行代码操作")
    map("n", "[g", function() vim.diagnostic.jump({ count = -1 }) end, "跳转到上一个诊断")
    map("n", "]g", function() vim.diagnostic.jump({ count = 1 }) end, "跳转到下一个诊断")
    map("n", "<leader>lf", function()
      format_with_lsp(event.buf)
    end, "使用当前文件的 LSP 格式化文档")
    map("x", "<leader>lf", function()
      format_with_lsp(event.buf, true)
    end, "使用当前文件的 LSP 格式化选中范围")

    -- [Advanced] 智能分屏跳转定义 (gD)
    map("n", "gD", function()
      local win = vim.api.nvim_get_current_win()
      local width = vim.api.nvim_win_get_width(win)
      local height = vim.api.nvim_win_get_height(win)
      local value = 8 * width - 20 * height
      if value < 0 then
        vim.cmd("split")
      else
        vim.cmd("vsplit")
      end
      vim.lsp.buf.definition()
    end, "智能分屏并跳转到定义")

    -- 函数首尾跳转 ([f / ]f)
    local function jump_to_symbol(position_type)
      local params = { textDocument = vim.lsp.util.make_text_document_params() }
      local responses = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, 1000)
      if not responses then return end

      local pos = vim.api.nvim_win_get_cursor(0)
      local line = pos[1] - 1

      local function find_symbol(symbols)
        for _, s in ipairs(symbols) do
          local range = s.range or (s.location and s.location.range)
          if range and line >= range.start.line and line <= range["end"].line then
            if s.children then
              local child = find_symbol(s.children)
              if child then return child end
            end
            return s
          end
        end
      end

      for _, resp in pairs(responses) do
        local sym = find_symbol(resp.result or {})
        if sym and sym.range then
          local target_line = (position_type == "start") and sym.range.start.line or sym.range["end"].line
          vim.api.nvim_win_set_cursor(0, { target_line + 1, 0 })
          return
        end
      end
    end

    map("n", "[f", function() jump_to_symbol("start") end, "跳转到函数开头")
    map("n", "]f", function() jump_to_symbol("end") end, "跳转到函数结尾")

    -- Inlay Hints (内联提示开关)
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      map("n", "<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
      end, "开关内嵌提示")
    end

    -- 代码折叠
    if client and client:supports_method("textDocument/foldingRange") then
      require("config.folding").use_lsp(event.buf)
    end

    -- 光标下单词高亮
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) and vim.bo.filetype ~= "bigfile" then
      local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })
      vim.api.nvim_create_autocmd("LspDetach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
        end,
      })
    end

    -- 侧边栏图标
    local signs = {
      Error = "󰅚 ",
      Warn  = "󰀪 ",
      Info  = "󰋽 ",
      Hint  = " ",
    }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
    end

    -- 光标悬浮自动触发诊断悬浮窗
    vim.api.nvim_create_autocmd("CursorHold", {
      buffer = event.buf,
      callback = function()
        -- focusable = false 保证弹窗不会抢走光标焦点
        vim.diagnostic.open_float(nil, { focusable = false })
      end
    })
  end,
})


vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- 强制重新触发 FileType 事件，让 LSP 立即执行初始诊断
    vim.cmd("silent! doautoall FileType")
  end,
})
