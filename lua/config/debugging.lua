local dap = require("dap")

-- ==========================================
-- 配置调试适配器 (Adapters)
-- 适配器是 Neovim 和底层调试器 (如 gdb, lldb) 之间的桥梁
-- ==========================================
dap.adapters.codelldb = {
  type = "executable",
  command = "codelldb", -- 如果不在系统环境变量 $PATH 中，请修改为绝对路径，例如："/absolute/path/to/codelldb"
}

dap.adapters.cppdbg = {
  id = "cppdbg",
  type = "executable",
  command = "OpenDebugAD7", -- 如果不在 $PATH 中："/absolute/path/to/OpenDebugAD7"
  options = { detached = false },
}

dap.adapters.gdb = {
  type = "executable",
  command = "gdb",
  -- 启用美化打印输出 (pretty-printing)
  args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
}

dap.adapters.cudagdb = {
  type = "executable",
  command = "cuda-gdb",
}

dap.adapters.python = {
  type = "executable",
  command = "/home/usharbisin/.virtualenvs/debugpy/bin/python",
  args = { "-m", "debugpy.adapter" }
}

-- ==========================================
-- 针对不同文件类型的调试配置 (Configurations)
-- 定义了如何启动或附加到特定语言的程序
-- ==========================================

-- CUDA 程序的调试配置
dap.configurations.cuda = {
  {
    name = "Launch (cuda-gdb)", -- 启动选项的名称
    type = "cudagdb",           -- 使用的适配器
    request = "launch",         -- 请求类型：启动 (launch) 或附加 (attach)
    program = function()
      -- 交互式输入要调试的可执行文件路径
      return vim.fn.input("可执行文件路径: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}", -- 工作目录设为当前工作区
    stopOnEntry = false,        -- 启动时不在入口点自动暂停
  },
  {
    name = "Launch (gdb)",
    type = "cppdbg",
    MIMode = "gdb",
    request = "launch",
    miDebuggerPath = "/usr/bin/gdb",
    program = function()
      return vim.fn.input("可执行文件路径: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}",
    setupCommands = {
      {
        description = "为 gdb 启用美化打印",
        ignoreFailures = true,
        text = "-enable-pretty-printing",
      },
    },
    stopAtBeginningOfMainSubprogram = false,
  },
}

-- C/C++ 程序的调试配置
dap.configurations.cpp = dap.configurations.cpp or {}
vim.list_extend(dap.configurations.cpp, {
  {
    name = "Launch (codelldb)",
    type = "codelldb",
    request = "launch",
    program = function()
      return vim.fn.input("可执行文件路径: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
  },
  {
    name = "Launch (gdb)",
    type = "cppdbg",
    MIMode = "gdb",
    request = "launch",
    miDebuggerPath = "/usr/bin/gdb",
    program = function()
      return vim.fn.input("可执行文件路径: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}",
    setupCommands = {
      {
        description = "为 gdb 启用美化打印",
        ignoreFailures = true,
        text = "-enable-pretty-printing",
      },
    },
    stopAtBeginningOfMainSubprogram = false,
  },
  {
    name = "Select and attach to process (选择并附加到进程)",
    type = "cppdbg",
    request = "attach",
    program = function()
      return vim.fn.input("可执行文件路径: ", vim.fn.getcwd() .. "/", "file")
    end,
    pid = function()
      -- 允许用户输入过滤器并从进程列表中选择 PID
      local name = vim.fn.input("可执行文件名称 (用于过滤): ")
      return require("dap.utils").pick_process({ filter = name })
    end,
    cwd = "${workspaceFolder}",
  },
})

-- Python 及特定项目 (如 Gaudi/Moore) 的高级调试配置
dap.configurations.python = dap.configurations.python or {}
vim.list_extend(dap.configurations.python, {
  {
    type = "python",
    request = "launch",
    name = "file",
    program = "${file}",
    console = "integratedTerminal",
    python = function()
      -- cicromamba 激活後，会自动注入 CONDA_PREFIX 环境变量
      local conda_prefix = os.getenv("CONDA_PREFIX")
      if conda_prefix then
        return conda_prefix .. "/bin/python"
      end
      -- 如果没激活 micromamba，就降级使用终端默认的 python
      return vim.fn.exepath("python")
    end,
    cwd = vim.fn.getcwd()
  },
  {
    type = "python",
    request = "launch",
    name = "file:args (cwd) - 带有参数的 Python 脚本",
    program = "${file}",
    args = function()
      local args_string = vim.fn.input("输入启动参数: ")
      local utils = require("dap.utils")
      if utils.splitstr and vim.fn.has("nvim-0.10") == 1 then
        return utils.splitstr(args_string)
      end
      return vim.split(args_string, " +")
    end,
    python = function()
      -- cicromamba 激活後，会自动注入 CONDA_PREFIX 环境变量
      local conda_prefix = os.getenv("CONDA_PREFIX")
      if conda_prefix then
        return conda_prefix .. "/bin/python"
      end
      -- 如果没激活 micromamba，就降级使用终端默认的 python
      return vim.fn.exepath("python")
    end,
    console = "integratedTerminal", -- 使用集成终端
    cwd = vim.fn.getcwd(),
  },
})

-- 将 Python 的配置完全复用到 qmt 文件类型上
dap.configurations.qmt = dap.configurations.python


-- ==========================================
-- 其他调试相关的插件初始化
-- ==========================================
-- 启用内联虚拟文本显示调试变量值
require("nvim-dap-virtual-text").setup()

-- 如果安装了 noice.nvim，则进行初始化
local ok, noice = pcall(require, "noice")
if ok then
  noice.setup()
end


-- ==========================================
-- DAP UI 界面自动响应与布局配置
-- ==========================================
local custom_utils = require 'config.utils'
local dapui = require('dapui')

-- UI 响应事件：在调试开始/结束时自动打开/关闭 UI 面板
dap.listeners.before.attach.dapui_config = function()
  dapui.open({ reset = true })
  custom_utils.reset_overseerlist_width()
end
dap.listeners.before.launch.dapui_config = function()
  dapui.open({ reset = true })
  custom_utils.reset_overseerlist_width()
end
dap.listeners.before.event_terminated.dapui_config = function()
  dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
  dapui.close()
end

-- 自定义 UI 布局结构
dapui.setup {
  expand_lines = false,
  layouts = {
    {
      -- 左侧面板布局
      position = 'left',
      size = 0.2,
      elements = {
        { id = 'stacks',      size = 0.2 },  -- 调用栈
        { id = 'scopes',      size = 0.5 },  -- 作用域及变量
        { id = 'breakpoints', size = 0.15 }, -- 断点列表
        { id = 'watches',     size = 0.15 }, -- 监视变量
      },
    },
    {
      -- 底部面板布局
      position = 'bottom',
      size = 0.2,
      elements = {
        { id = 'repl',    size = 0.3 }, -- 交互式调试终端 (REPL)
        { id = 'console', size = 0.7 }, -- 输出控制台
      },
    },
  },
}

-- fg 代表前景颜色 (文字/图标颜色)
vim.api.nvim_set_hl(0, 'DapBreakpoint', { fg = '#e51400' })          -- 普通断点：红色
vim.api.nvim_set_hl(0, 'DapBreakpointCondition', { fg = '#ffcc00' }) -- 条件断点：黄色
vim.api.nvim_set_hl(0, 'DapStopped', { fg = '#98c379' })             -- 当前停靠行：绿色
vim.api.nvim_set_hl(0, 'DapStoppedLine', { bg = '#2d4f33' })         -- 当前停靠行的背景：深邃莫兰迪绿
-- 自定义左侧行号区域的断点图标样式
vim.fn.sign_define('DapBreakpoint', { text = '', texthl = 'DapBreakpoint', linehl = '', numhl = 'DapBreakpoint' })
vim.fn.sign_define(
  'DapBreakpointCondition',
  { text = '', texthl = 'DapBreakpointCondition', linehl = 'DapBreakpointCondition', numhl = 'DapBreakpointCondition' }
)
vim.fn.sign_define('DapStopped', { text = '', texthl = 'DapStopped', linehl = 'DapStoppedLine', numhl = 'DapStopped' })


-- ==========================================
-- 快捷键映射 (Keymaps)
-- ==========================================
-- 界面切换
vim.keymap.set('n', '<leader>du', function()
  dapui.toggle({ reset = true })
  custom_utils.reset_overseerlist_width()
end, { desc = 'DAP: 切换 UI 面板' })
vim.keymap.set('n', '<F1>', function()
  dapui.toggle({ reset = true })
  custom_utils.reset_overseerlist_width()
end, { desc = 'DAP: 切换 UI 面板' })

-- 核心执行与步进操作
vim.keymap.set('n', '<leader>ds', dap.continue, { desc = 'DAP: 启动 / 继续执行' })
vim.keymap.set('n', '<F2>', dap.continue, { desc = 'DAP: 启动 / 继续执行' })
vim.keymap.set('n', '<leader>di', dap.step_into, { desc = 'DAP: 单步进入 (Step into)' })
vim.keymap.set('n', '<F3>', dap.step_into, { desc = 'DAP: 单步进入 (Step into)' })
vim.keymap.set('n', '<leader>do', dap.step_over, { desc = 'DAP: 单步跳过 (Step over)' })
vim.keymap.set('n', '<F4>', dap.step_over, { desc = 'DAP: 单步跳过 (Step over)' })
vim.keymap.set('n', '<leader>dO', dap.step_out, { desc = 'DAP: 单步跳出 (Step out)' })
vim.keymap.set('n', '<F5>', dap.step_out, { desc = 'DAP: 单步跳出 (Step out)' })

-- 调试会话控制
vim.keymap.set('n', '<leader>dq', dap.close, { desc = 'DAP: 关闭当前会话' })
vim.keymap.set('n', '<leader>dr', dap.restart_frame, { desc = 'DAP: 重启当前栈帧' })
vim.keymap.set('n', '<F6>', dap.restart, { desc = 'DAP: 从头重新开始调试' })
vim.keymap.set('n', '<leader>dQ', dap.terminate, { desc = 'DAP: 强制终止调试' })
vim.keymap.set('n', '<F7>', dap.terminate, { desc = 'DAP: 强制终止调试' })

-- 杂项工具
vim.keymap.set('n', '<leader>dc', dap.run_to_cursor, { desc = 'DAP: 运行到光标处' })
vim.keymap.set('n', '<leader>dR', dap.repl.toggle, { desc = 'DAP: 切换交互终端 (REPL)' })
vim.keymap.set('n', '<leader>dh', require('dap.ui.widgets').hover, { desc = 'DAP: 悬浮查看变量值' })

-- 断点管理
vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint, { desc = 'DAP: 切换当前行断点' })
vim.keymap.set('n', '<leader>dB', function()
  local input = vim.fn.input '输入条件断点的触发条件: '
  dap.set_breakpoint(input)
end, { desc = 'DAP: 添加条件断点' })
vim.keymap.set('n', '<leader>dD', dap.clear_breakpoints, { desc = 'DAP: 清除所有断点' })
