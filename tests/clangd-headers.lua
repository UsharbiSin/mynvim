local path = vim.fn.tempname() .. ".c"
vim.fn.writefile({ "#include <stdio.h>", "int main(void) { return 0; }" }, path)
vim.cmd.edit(vim.fn.fnameescape(path))
local buffer = vim.api.nvim_get_current_buf()

assert(vim.wait(10000, function()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buffer })) do
    if client.name == "clangd" then return true end
  end
end, 100), "clangd must attach to a standalone C file")

local params = { textDocument = vim.lsp.util.make_text_document_params(buffer) }
assert(
  vim.lsp.buf_request_sync(buffer, "textDocument/documentSymbol", params, 10000),
  "clangd must process the standalone C file"
)
vim.wait(500)
for _, diagnostic in ipairs(vim.diagnostic.get(buffer)) do
  assert(
    not diagnostic.message:lower():find("file not found", 1, true),
    "clangd must find GCC system headers: " .. diagnostic.message
  )
end

vim.api.nvim_buf_delete(buffer, { force = true })
vim.fn.delete(path)
print("PASS: clangd GCC system headers")
vim.cmd("qa!")
