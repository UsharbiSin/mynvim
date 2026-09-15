local M = {}

local supported_filetypes = { markdown = true, vimwiki = true }
local lsp_languages = { "python", "lua", "c", "cpp", "java", "javascript", "html", "json", "sql" }
local publish_diagnostics = vim.lsp.protocol.Methods.textDocument_publishDiagnostics

local function is_e303(diagnostic)
  return tostring(diagnostic.code or ""):upper() == "E303"
      or (diagnostic.message or ""):match("^E303[%s:]") ~= nil
end

local function is_json_end_of_file_expected(diagnostic)
  return (diagnostic.message or ""):lower() == "end of file expected."
end

local function filter_diagnostics(result)
  if not result or not result.uri then
    return result
  end

  local uri = result.uri:lower()
  local is_python_raft = uri:match("%.otter%.py$") ~= nil
  local is_json_raft = uri:match("%.otter%.json$") ~= nil
  if not is_python_raft and not is_json_raft then return result end

  result = vim.deepcopy(result)
  result.diagnostics = vim.tbl_filter(function(diagnostic)
    if is_python_raft and is_e303(diagnostic) then return false end
    if is_json_raft and is_json_end_of_file_expected(diagnostic) then return false end
    return true
  end, result.diagnostics or {})
  return result
end

local function filter_markdown_raft_diagnostics(client)
  if client._markdown_otter_diagnostic_filter then return end
  client._markdown_otter_diagnostic_filter = true
  local original = client.handlers[publish_diagnostics] or vim.lsp.handlers[publish_diagnostics]
  client.handlers[publish_diagnostics] = function(error, result, context, config)
    return original(error, filter_diagnostics(result), context, config)
  end
end

local function activate(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) or not supported_filetypes[vim.bo[buffer].filetype] then
    return
  end
  if vim.bo[buffer].buftype ~= "" then
    return
  end
  local keeper_ok, keeper = pcall(require, "otter.keeper")
  if keeper_ok and keeper.rafts[buffer] then return end

  vim.api.nvim_buf_call(buffer, function()
    require("otter").activate(lsp_languages, true, true)
  end)
end

function M.setup()
  require("otter").setup({
    lsp = {
      diagnostic_update_events = { "BufWritePost", "InsertLeave", "TextChanged" },
      root_dir = function(_, buffer)
        return vim.fs.root(buffer or 0, { ".git", "pyproject.toml", "package.json" })
            or vim.fn.getcwd(0)
      end,
    },
    buffers = {
      set_filetype = true,
      write_to_disk = false,
    },
    handle_leading_whitespace = true,
    verbose = { no_code_found = false },
  })

  local group = vim.api.nvim_create_augroup("markdown_embedded_lsp", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "markdown", "vimwiki" },
    callback = function(args)
      vim.schedule(function()
        activate(args.buf)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local name = vim.api.nvim_buf_get_name(args.buf):lower()
      if name:match("%.otter%.py$") or name:match("%.otter%.json$") then
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and (client.name == "pylsp" or client.name == "jsonls") then
          filter_markdown_raft_diagnostics(client)
        end
      end
    end,
  })

  vim.schedule(function()
    activate(vim.api.nvim_get_current_buf())
  end)
end

M.filter_diagnostics = filter_diagnostics

return M
