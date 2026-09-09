vim.opt.rtp:prepend(vim.fn.getcwd())
local m = require('config.image-inline')
assert(m.size_from_panes({}, '1') == nil)
assert(m.size_from_panes({ { pane_id = 1, size = { cols = 0 } } }, '1') == nil)
local s = assert(m.size_from_panes({
  { pane_id = 2, size = { cols = 100, rows = 40, pixel_width = 900, pixel_height = 720 } },
}, '2'))
assert(s.cell_width == 9 and s.cell_height == 18)
assert(m.size_from_panes({ { pane_id = 3, size = {} } }, '2') == nil)
assert(loadfile('lua/config/snacks.lua'))
assert(loadfile('lua/plugins/plugin-list.lua'))
print('PASS: inline image dimensions and configuration syntax')

local scheduled, scans, clears, renders = {}, 0, 0, 0
local original_schedule = vim.schedule
local original_defer_fn = vim.defer_fn
vim.schedule = function(fn) table.insert(scheduled, fn) end
vim.defer_fn = function(fn)
  table.insert(scheduled, fn)
  return { stop = function() end, close = function() end }
end
vim.bo.filetype = 'markdown'
vim.api.nvim_create_autocmd('BufEnter', {
  group = vim.api.nvim_create_augroup('image.nvim:markdown', { clear = true }),
  callback = function() scans = scans + 1 end,
})
local item = {
  id = 'fixture', buffer = vim.api.nvim_get_current_buf(), window = vim.api.nvim_get_current_win(),
  padding = false,
  get_extmark_id = function(self) return self.padding and 1 or nil end,
  global_state = { backend = { clear = function(_, shallow)
    assert(shallow == true)
    clears = clears + 1
  end } },
  render = function(self)
    renders = renders + 1
    self.padding = true
  end,
}
package.loaded.image = {
  is_enabled = function() return true end,
  get_images = function() return { item } end,
}
package.loaded['snacks.image.doc'] = {
  find = function(_, callback) callback({}) end,
}
m.refresh(true)
while #scheduled > 0 do table.remove(scheduled, 1)() end
assert(scans == 1, 'refresh must trigger one targeted document scan')
item:render()
while #scheduled > 0 do table.remove(scheduled, 1)() end
assert(clears == 0 and renders == 1, 'padding refresh must not retransmit the image')
item:render()
while #scheduled > 0 do table.remove(scheduled, 1)() end
assert(clears == 0 and renders == 2, 'stable padding must not clear the image')

local conversions = 0
local aborted = 0
Snacks = {
  image = {
    convert = {
      convert = function()
        conversions = conversions + 1
        return {
          run = function() end,
          abort = function() aborted = aborted + 1 end,
        }
      end,
    },
  },
}
package.loaded['snacks.image.doc'].find = function(_, callback)
  callback({ { id = 77, type = 'math', src = 'formula.math.tex', pos = { 1, 0 } } })
end
m.refresh()
m.refresh()
while #scheduled > 0 do table.remove(scheduled, 1)() end
assert(conversions == 1, 'a pending formula must start only one conversion')

local find_opts
package.loaded['snacks.image.doc'].find = function(_, callback, opts)
  find_opts = opts
  local items = {}
  for id = 1, 10 do
    items[id] = { id = id, type = 'math', src = id .. '.math.tex', pos = { id, 0 } }
  end
  callback(items)
end
conversions = 0
m.refresh()
while #scheduled > 0 do table.remove(scheduled, 1)() end
assert(conversions < 10, 'formulas outside the viewport must not be converted')
assert(find_opts and find_opts.from and find_opts.to, 'formula parsing must be limited to the viewport')
assert(aborted == 1, 'a pending formula outside the viewport must be aborted')
vim.schedule = original_schedule
vim.defer_fn = original_defer_fn
print('PASS: padding refresh and formula conversion deduplication')
