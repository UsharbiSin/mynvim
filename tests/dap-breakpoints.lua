local source = vim.fn.tempname() .. ".py"
local store = vim.fn.tempname() .. ".json"
vim.fn.writefile({
  "print('one')",
  "print('two')",
  "print('three')",
  "print('four')",
  "print('five')",
}, source)

local bp_state = {}
local function list_for(bufnr)
  bp_state[bufnr] = bp_state[bufnr] or {}
  return bp_state[bufnr]
end

local fake_breakpoints = {}
function fake_breakpoints.get(bufnr)
  if bufnr then
    local list = bp_state[bufnr]
    return list and { [bufnr] = vim.deepcopy(list) } or {}
  end
  return vim.deepcopy(bp_state)
end

function fake_breakpoints.set(opts, bufnr, line)
  local list = list_for(bufnr)
  for index = #list, 1, -1 do
    if list[index].line == line then
      table.remove(list, index)
    end
  end
  list[#list + 1] = {
    buf = bufnr,
    line = line,
    condition = opts.condition,
    hitCondition = opts.hit_condition,
    logMessage = opts.log_message,
  }
end

package.loaded["dap.breakpoints"] = fake_breakpoints
package.loaded["config.dap-breakpoints"] = nil

local dap = {}
function dap.toggle_breakpoint(condition, hit_condition, log_message, replace_old)
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local list = list_for(bufnr)
  local found
  for index, bp in ipairs(list) do
    if bp.line == line then
      found = index
      break
    end
  end
  if found then
    table.remove(list, found)
    if not replace_old then return end
  end
  list[#list + 1] = {
    buf = bufnr,
    line = line,
    condition = condition,
    hitCondition = hit_condition,
    logMessage = log_message,
  }
end
function dap.set_breakpoint(condition, hit_condition, log_message)
  return dap.toggle_breakpoint(condition, hit_condition, log_message, true)
end
function dap.clear_breakpoints()
  bp_state = {}
end
function dap.session()
  return nil
end

local bufnr = vim.fn.bufadd(source)
vim.fn.bufload(bufnr)
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_win_set_cursor(0, { 2, 0 })

local persistence = require("config.dap-breakpoints")
persistence.setup(dap, { store_path = store })
vim.wait(20)

dap.toggle_breakpoint()
assert(vim.fn.filereadable(store) == 1, "toggling a breakpoint must create the persistence file")

vim.api.nvim_win_set_cursor(0, { 4, 0 })
dap.set_breakpoint("x > 1", "3", "x={x}")

local decoded = vim.json.decode(table.concat(vim.fn.readfile(store), "\n"))
local key = vim.fs.normalize(vim.fn.fnamemodify(source, ":p"))
assert(type(decoded.files[key]) == "table" and #decoded.files[key] == 2,
  "ordinary and conditional breakpoints must both be persisted")
assert(decoded.files[key][1].line == 2, "ordinary breakpoint line must be persisted")
assert(decoded.files[key][2].line == 4, "conditional breakpoint line must be persisted")
assert(decoded.files[key][2].condition == "x > 1", "breakpoint condition must be persisted")
assert(decoded.files[key][2].hit_condition == "3", "hit condition must be persisted")
assert(decoded.files[key][2].log_message == "x={x}", "log message must be persisted")

-- Simulate a sign moving with edited text; BufWritePost must persist the new line.
bp_state[bufnr][1].line = 3
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = bufnr })
decoded = vim.json.decode(table.concat(vim.fn.readfile(store), "\n"))
assert(decoded.files[key][1].line == 3, "saving the file must persist moved breakpoint lines")

-- Simulate closing/reopening the file without using clear_breakpoints(), so the
-- persisted file remains the source of truth for the new buffer.
vim.api.nvim_buf_delete(bufnr, { force = true })
bp_state = {}
local reopened = vim.fn.bufadd(source)
vim.fn.bufload(reopened)
vim.api.nvim_set_current_buf(reopened)
vim.wait(20)

local restored = bp_state[reopened] or {}
table.sort(restored, function(left, right) return left.line < right.line end)
assert(#restored == 2, "reopening a file must automatically restore its breakpoints")
assert(restored[1].line == 3 and restored[2].line == 4, "restored breakpoint lines must match saved lines")
assert(restored[2].condition == "x > 1", "restored conditional breakpoint must keep its condition")
assert(restored[2].hitCondition == "3", "restored conditional breakpoint must keep its hit condition")
assert(restored[2].logMessage == "x={x}", "restored conditional breakpoint must keep its log message")

dap.clear_breakpoints()
decoded = vim.json.decode(table.concat(vim.fn.readfile(store), "\n"))
assert(next(decoded.files) == nil, "clear_breakpoints must also clear persisted breakpoints")

print("PASS: persistent DAP breakpoints")
