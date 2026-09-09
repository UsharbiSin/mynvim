local M = {}

local supported_filetypes = { markdown = true, vimwiki = true }
local lsp_languages = { "python", "lua", "c", "cpp", "html", "json", "sql" }

local function activate(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) or not supported_filetypes[vim.bo[buffer].filetype] then
    return
  end
  if vim.bo[buffer].buftype ~= "" then
    return
  end

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

  vim.schedule(function()
    activate(vim.api.nvim_get_current_buf())
  end)
end

return M
