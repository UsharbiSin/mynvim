local credentials = require("config.sql-credentials")

-- 只保存无秘密的连接模板；实际取密由 mysql 子进程边界处理。
require("config.sql-credentials.grip").install()
vim.g.dbs = credentials.connections()

require("dadbod-grip").setup({
  ai = false,
  completion = false,
  discovery = false,
  limit = 1000,
  timeout = 300000,
})

require("config.sql-browser").setup()
