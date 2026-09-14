local M = {}

local dap_ref
local store_path
local store_cache
local setup_done = false
local restoring = {}

local function default_store_path()
  local base = vim.fn.stdpath("state")
  if not base or base == "" then
    base = vim.fn.stdpath("data")
  end
  return vim.fs.joinpath(base, "dap-breakpoints.json")
end

local function buffer_path(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then return nil end
  return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

local function load_store()
  if store_cache then return store_cache end

  store_cache = { version = 1, files = {} }
  if vim.fn.filereadable(store_path) ~= 1 then
    return store_cache
  end

  local ok_read, lines = pcall(vim.fn.readfile, store_path)
  if not ok_read or #lines == 0 then
    return store_cache
  end

  local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if ok_decode and type(decoded) == "table" and type(decoded.files) == "table" then
    store_cache = decoded
    store_cache.version = 1
  end
  return store_cache
end

local function write_store()
  local dir = vim.fn.fnamemodify(store_path, ":h")
  vim.fn.mkdir(dir, "p")

  local ok_encode, encoded = pcall(vim.json.encode, load_store())
  if not ok_encode then
    vim.notify("DAP 断点保存失败：无法编码断点数据", vim.log.levels.ERROR)
    return false
  end

  local ok_write, err = pcall(vim.fn.writefile, { encoded }, store_path)
  if not ok_write then
    vim.notify("DAP 断点保存失败：" .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.save_buffer(bufnr, flush)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = buffer_path(bufnr)
  if not path then return false end

  local breakpoints = require("dap.breakpoints").get(bufnr)[bufnr] or {}
  local saved = {}
  for _, bp in pairs(breakpoints) do
    if bp.line and bp.line > 0 then
      saved[#saved + 1] = {
        line = bp.line,
        condition = bp.condition,
        hit_condition = bp.hitCondition,
        log_message = bp.logMessage,
      }
    end
  end
  table.sort(saved, function(left, right)
    return left.line < right.line
  end)

  local files = load_store().files
  files[path] = #saved > 0 and saved or nil
  if flush ~= false then
    return write_store()
  end
  return true
end

function M.restore_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = buffer_path(bufnr)
  if not path then return false end

  local saved = load_store().files[path]
  if type(saved) ~= "table" or #saved == 0 then return false end

  local breakpoints = require("dap.breakpoints")
  restoring[bufnr] = true
  for _, bp in ipairs(saved) do
    local line = tonumber(bp.line)
    if line and line > 0 then
      breakpoints.set({
        condition = bp.condition,
        hit_condition = bp.hit_condition,
        log_message = bp.log_message,
      }, bufnr, line)
    end
  end
  restoring[bufnr] = nil

  local session = dap_ref and dap_ref.session and dap_ref.session()
  if session then
    pcall(session.set_breakpoints, session, breakpoints.get(bufnr))
  end
  return true
end

local function save_loaded_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.save_buffer(bufnr, false)
    end
  end
  write_store()
end

function M.setup(dap, opts)
  if setup_done then return end
  setup_done = true
  dap_ref = dap
  opts = opts or {}
  store_path = opts.store_path or default_store_path()

  local original_toggle_breakpoint = dap.toggle_breakpoint
  dap.toggle_breakpoint = function(...)
    local bufnr = vim.api.nvim_get_current_buf()
    local result = original_toggle_breakpoint(...)
    if not restoring[bufnr] then
      M.save_buffer(bufnr)
    end
    return result
  end

  local original_clear_breakpoints = dap.clear_breakpoints
  dap.clear_breakpoints = function(...)
    local result = original_clear_breakpoints(...)
    load_store().files = {}
    write_store()
    return result
  end

  local group = vim.api.nvim_create_augroup("DapPersistentBreakpoints", { clear = true })
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(event)
      M.restore_buffer(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufUnload" }, {
    group = group,
    callback = function(event)
      M.save_buffer(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = save_loaded_buffers,
  })

  -- nvim-dap 按 FileType 懒加载时，已有缓冲区的 BufReadPost 可能已经发生，
  -- 因此配置加载完成后主动恢复全部已加载文件，避免退出时把旧断点误写成已清空。
  vim.schedule(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        M.restore_buffer(bufnr)
      end
    end
  end)
end

function M.store_path()
  return store_path or default_store_path()
end

return M
