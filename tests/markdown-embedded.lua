local buffer = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buffer)
vim.bo[buffer].filetype = "markdown"
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
  "```json", '{ "broken": }', "```", "",
  "```c", "#include <stdio.h>", "int main(void) { return 0; }", "```", "",
  "```c++", "#include <vector>", "class Demo {};", "```", "",
  "```java", "class Demo {}", "```", "",
  "```javascript", "const value = true;", "```", "",
  "```html", "<main>text</main>", "```",
})

local parser = vim.treesitter.get_parser(buffer, "markdown")
parser:parse(true)
local languages = {}
parser:for_each_tree(function(_, tree)
  languages[tree:lang()] = true
end)

for _, language in ipairs({ "json", "c", "cpp", "java", "javascript", "html" }) do
  assert(
    languages[language],
    "missing Markdown Tree-sitter injection: " .. language .. "; got " .. table.concat(vim.tbl_keys(languages), ",")
  )
end

assert(vim.lsp.is_enabled("jsonls"), "jsonls must be enabled")
assert(vim.lsp.is_enabled("clangd"), "clangd must be enabled for C/C++")
assert(vim.lsp.is_enabled("ts_ls"), "ts_ls must be enabled for JavaScript")
assert(vim.lsp.is_enabled("html"), "html LSP must be enabled")
assert(vim.treesitter.language.get_lang("jsonc") == "json", "JSONC must reuse the JSON parser")
assert(vim.treesitter.language.get_lang("c++") == "cpp", "c++ fences must reuse the C++ parser")
assert(require("ibl.scope_languages").json.object, "JSON object must be an indent scope")
assert(require("ibl.scope_languages").json.array, "JSON array must be an indent scope")

assert(vim.wait(15000, function()
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.name == "jsonls" then return true end
  end
end, 100), "jsonls must attach to the embedded JSON buffer")
vim.api.nvim_buf_set_lines(buffer, 1, 2, false, { '{ "broken": , }' })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = buffer })
local diagnosed = vim.wait(15000, function()
  return #vim.diagnostic.get(buffer, { severity = vim.diagnostic.severity.ERROR }) > 0
end, 100)
if not diagnosed then
  error("invalid embedded JSON must publish a diagnostic in the Markdown buffer")
end
for _, diagnostic in ipairs(vim.diagnostic.get(buffer)) do
  assert(
    not diagnostic.message:lower():find("file not found", 1, true),
    "Markdown C/C++ standard headers must follow the configured GCC toolchain: " .. diagnostic.message
  )
end

print("PASS: Markdown embedded language highlighting and LSP configuration")
vim.cmd("qa!")
