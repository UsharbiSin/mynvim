local M = {}

local normal_layout = "1033"
local insert_layout = "2052"
local weasel_server
local ffi
local kernel32

local function find_weasel_server()
  local root = vim.env.ProgramFiles
  if not root or root == "" then
    return nil
  end
  local pattern = vim.fs.joinpath(root, "Rime", "weasel-*", "WeaselServer.exe")
  local servers = vim.fn.glob(pattern, false, true)
  table.sort(servers)
  return servers[#servers]
end

local function load_pipe_api()
  local ok
  ok, ffi = pcall(require, "ffi")
  if not ok then
    return false
  end
  pcall(ffi.cdef, [[
    void *CreateFileW(const uint16_t *name, uint32_t access, uint32_t share,
      void *security, uint32_t creation, uint32_t flags, void *template_file);
    int SetNamedPipeHandleState(void *pipe, uint32_t *mode, void *max_collection, void *timeout);
    int WriteFile(void *file, const void *buffer, uint32_t size, uint32_t *written, void *overlapped);
    int ReadFile(void *file, void *buffer, uint32_t size, uint32_t *read, void *overlapped);
    int CloseHandle(void *object);
    uint32_t GetLastError(void);
  ]])
  local loaded
  loaded, kernel32 = pcall(ffi.load, "kernel32")
  return loaded
end

local function wide_string(value)
  local result = ffi.new("uint16_t[?]", #value + 1)
  for index = 1, #value do
    result[index - 1] = value:byte(index)
  end
  return result
end

local function connect_pipe()
  local username = vim.env.USERNAME
  if not username then
    return nil
  end
  local name = wide_string("\\\\.\\pipe\\" .. username .. "\\WeaselNamedPipe")
  local pipe = kernel32.CreateFileW(name, 0xC0000000, 0, nil, 3, 0, nil)
  if pipe == ffi.cast("void *", -1) then
    return nil, "CreateFileW: " .. tonumber(kernel32.GetLastError())
  end
  local mode = ffi.new("uint32_t[1]", 2)
  if kernel32.SetNamedPipeHandleState(pipe, mode, nil, nil) == 0 then
    kernel32.CloseHandle(pipe)
    return nil, "SetNamedPipeHandleState: " .. tonumber(kernel32.GetLastError())
  end
  return pipe
end

local function transaction(pipe, message, wparam, lparam, body)
  body = body or ""
  local encoded = wide_string(body)
  local body_size = #body * 2
  local request = ffi.new("uint8_t[?]", 12 + body_size)
  local header = ffi.cast("uint32_t *", request)
  header[0], header[1], header[2] = message, wparam, lparam
  if body_size > 0 then
    ffi.copy(ffi.cast("uint8_t *", request) + 12, encoded, body_size)
  end

  local transferred = ffi.new("uint32_t[1]")
  if kernel32.WriteFile(pipe, request, 12 + body_size, transferred, nil) == 0 then
    return nil, "WriteFile: " .. tonumber(kernel32.GetLastError())
  end
  local response = ffi.new("uint8_t[?]", 65536)
  if kernel32.ReadFile(pipe, response, 65536, transferred, nil) == 0 or transferred[0] < 4 then
    return nil, "ReadFile: " .. tonumber(kernel32.GetLastError())
  end
  return response, tonumber(transferred[0]), tonumber(ffi.cast("uint32_t *", response)[0])
end

local function query_ascii_mode()
  if not kernel32 then
    return nil
  end
  local pipe, pipe_error = connect_pipe()
  if not pipe then
    return nil, pipe_error
  end

  local body = table.concat({
    "action=session",
    "session.client_app=wezterm-gui.exe",
    "session.client_type=tsf",
    ".",
    "",
  }, "\r\n")
  local _, _, session = transaction(pipe, 0x8002, 0, 0, body)
  if not session or session == 0 then
    kernel32.CloseHandle(pipe)
    return nil, "小狼毫没有创建查询会话"
  end

  local response, size = transaction(pipe, 0x8004, 0, session)
  transaction(pipe, 0x8003, 0, session)
  kernel32.CloseHandle(pipe)
  if not response then
    return nil, "小狼毫没有返回状态"
  end
  local data = ffi.cast("uint8_t *", response) + 4
  local characters = {}
  for offset = 0, size - 6, 2 do
    local byte = tonumber(data[offset])
    if byte == 0 and tonumber(data[offset + 1]) == 0 then
      break
    end
    characters[#characters + 1] = string.char(byte)
  end
  local text = table.concat(characters)
  local value = text:match("status%.ascii_mode=(%d)")
  if not value then
    return nil, "小狼毫响应中缺少 ascii_mode"
  end
  return value == "1"
end

local function current_layout()
  return vim.trim(vim.fn.system({ "im-select.exe" }))
end

local function switch_layout(layout)
  if current_layout() == layout then
    return true
  end
  return vim.system({ "im-select.exe", layout }):wait(500).code == 0
end

local function set_ascii_mode(ascii_mode)
  if not weasel_server then
    return
  end
  vim.system({ weasel_server, ascii_mode and "/ascii" or "/nascii" }):wait(500)
end

M.current_ascii_mode = query_ascii_mode

function M.setup()
  if vim.g.is_win ~= 1 or vim.fn.executable("im-select.exe") ~= 1 then
    return
  end
  load_pipe_api()
  weasel_server = find_weasel_server()

  -- 每次启动默认英文；仅在本次 Neovim 会话中记住后续切换。
  local ascii_mode = true

  local function enter_input_mode()
    if switch_layout(insert_layout) then
      set_ascii_mode(ascii_mode)
    end
  end

  local function leave_input_mode()
    if current_layout() == insert_layout then
      local current = query_ascii_mode()
      if current ~= nil then
        ascii_mode = current
      end
    end
    switch_layout(normal_layout)
  end

  local group = vim.api.nvim_create_augroup("windows-ime", { clear = true })
  vim.api.nvim_create_autocmd({ "InsertEnter", "TermEnter" }, {
    group = group,
    callback = enter_input_mode,
  })
  vim.api.nvim_create_autocmd({ "InsertLeave", "TermLeave" }, {
    group = group,
    callback = leave_input_mode,
  })
  switch_layout(normal_layout)
end

return M
