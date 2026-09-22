-- snacks.nvim 动态模式渲染配置 (Normal渲染，其他模式纯文本)
require("snacks").setup({
  terminal = { enabled = true },
  toggle = { enable = true },
  notifier = { enabled = false },
  image = {
    enabled = true,
    doc = {
      enabled = not require('config.image-inline').enabled(),
      -- 开启行内渲染
      inline = true,
      -- 悬浮窗
      float = false,
      max_width = 80,
    },
  }
})

require("config.codex").setup()
require('config.image-inline').setup_toggle()

-- Linux 使用 Snacks 原生 inline；运行时开关关闭后阻止已有实例重新创建 placement。
if not require('config.image-inline').is_windows() then
  local inline = require('snacks.image.inline')
  local original_update = inline.update
  inline.update = function(self)
    if not require('config.image-inline').active() then
      for _, image in pairs(self.imgs) do image:close() end
      self.imgs, self.idx = {}, {}
      return
    end
    return original_update(self)
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
  -- 解决 Vimwiki 文件类型被 Snacks 无视的问题
  -- 当进入 vimwiki 或 markdown 文件时，强制触发 Snacks 的文档图片渲染解析
  pattern = { "vimwiki", "markdown" },
  callback = function(args)
    if require('config.image-inline').enabled() then return end
    -- 安全地强制把当前 buffer 喂给 snacks 渲染引擎
    if Snacks and Snacks.image and Snacks.image.doc then
      pcall(Snacks.image.doc.attach, args.buf)
    end
  end
})
