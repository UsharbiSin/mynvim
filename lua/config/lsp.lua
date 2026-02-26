-- 唤醒 nvim-lspconfig，它会自动把所有已知语言的默认配置注册到底层 vim.lsp.config 中
-- require("lazydev").setup({})
require("lspconfig")

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


-- ==========================================
-- LspAttach 回调：统一设置快捷键与 UI 逻辑
-- ==========================================
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("SetupLSP", {}),
  callback = function(event)
    local client = assert(vim.lsp.get_client_by_id(event.data.client_id))

    -- 开启 LSP 语义高亮 (Semantic Tokens)
    if client.server_capabilities.semanticTokensProvider then
      vim.lsp.semantic_tokens.start(event.buf, client.id)
    end

    local function map(mode, keys, func, desc)
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
    end

    -- [Keymaps] 快捷键映射
    map("n", "gd", vim.lsp.buf.definition, "Goto Definition (跳转定义)")
    map("n", "gr", vim.lsp.buf.references, "Goto References (查看引用)")
    map("n", "gi", vim.lsp.buf.implementation, "Goto Implementation (跳转实现)")
    map("n", "gy", vim.lsp.buf.type_definition, "Goto Type Definition (跳转类型定义)")
    map("n", "K", vim.lsp.buf.hover, "Hover Documentation (悬浮文档)")
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename (重命名)")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action (代码操作)")
    map("n", "[g", function() vim.diagnostic.jump({ count = -1 }) end, "Previous Diagnostic (上一个错误)")
    map("n", "]g", function() vim.diagnostic.jump({ count = 1 }) end, "Next Diagnostic (下一个错误)")
    map("n", "<leader>lf", vim.lsp.buf.format, "Format Document (格式化)")

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
    end, "Goto Definition (Split Smartly)")

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

    map("n", "[f", function() jump_to_symbol("start") end, "Jump to function start")
    map("n", "]f", function() jump_to_symbol("end") end, "Jump to function end")

    -- Inlay Hints (内联提示开关)
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
      map("n", "<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
      end, "Toggle Inlay Hints")
    end

    -- 代码折叠
    if client and client:supports_method("textDocument/foldingRange") then
      local win = vim.api.nvim_get_current_win()
      vim.wo[win][0].foldmethod = "expr"
      vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
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

    -- 诊断样式配置
    vim.diagnostic.config({
      virtual_text = false,  -- 行尾报错文本
      virtual_lines = false, -- 报错文本的虚拟行
      signs = true,          -- 图标
      underline = true,      -- 报错代码的波浪线提示
      update_in_insert = false,
      float = { source = true, border = "rounded" },
    })

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
