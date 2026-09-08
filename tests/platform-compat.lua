-- 使用任意平台的 Neovim 模拟 Linux，检查 windows 分支的运行时平台选择。
vim.g.is_win = 0
dofile(vim.fs.joinpath(vim.fn.getcwd(), "lua", "core", "options.lua"))
assert(vim.o.foldmethod == "manual", "Linux must use manual folds by default")

local plugins = dofile(vim.fs.joinpath(vim.fn.getcwd(), "lua", "plugins", "plugin-list.lua"))
local by_name = {}
for _, plugin in ipairs(plugins) do
  by_name[plugin[1]] = plugin
end

assert(by_name["h-hg/fcitx.nvim"].cond(), "Linux must enable fcitx.nvim")
assert(not by_name["keaising/im-select.nvim"].cond(), "Linux must disable im-select.nvim")

local runner = dofile(vim.fs.joinpath(vim.fn.getcwd(), "lua", "core", "runner.lua"))
local c = assert(runner.spec("c", "/tmp/source.c"))
assert(c.run[1] == "/tmp/source", "Linux C output must not use the .exe suffix")

print("PASS: Linux compatibility conditions")
