local markdown = require("diagram.integrations.markdown")
markdown.filetypes = { "markdown", "vimwiki" }

if require("config.image-inline").enabled() then
  -- diagram.nvim 的缓存键不包含渲染参数；给源码增加无效果的版本注释，使尺寸调整生效。
  local cache_version = "adaptive-size-v3"
  local comments = {
    mermaid = "%% " .. cache_version,
    plantuml = "' " .. cache_version,
    d2 = "# " .. cache_version,
    gnuplot = "# " .. cache_version,
  }
  local function version_cache_key(renderer, comment)
    if renderer._adaptive_cache_key then return end
    renderer._adaptive_cache_key = true
    local original_render = renderer.render
    renderer.render = function(source, options)
      return original_render(comment .. "\n" .. source, options)
    end
  end
  for name, comment in pairs(comments) do
    local renderer = require("diagram.renderers." .. name)
    version_cache_key(renderer, comment)
  end

  -- 图表按当前窗口正文宽度显示；PNG 仍以高分辨率生成，避免放大后模糊。
  local image = require("image")
  if not image._diagram_adaptive_width then
    image._diagram_adaptive_width = true
    local original_from_file = image.from_file
    image.from_file = function(path, options)
      options = options or {}
      local normalized = path:gsub("\\", "/")
      local is_diagram = normalized:find("/diagram%-cache/", 1) ~= nil
      if is_diagram and options.window and vim.api.nvim_win_is_valid(options.window) then
        local info = vim.fn.getwininfo(options.window)[1]
        options = vim.tbl_extend("force", {}, options, {
          width = math.max(1, math.floor((info.width - info.textoff) * 0.9)),
          height = 0,
        })
      end
      local result = original_from_file(path, options)
      if is_diagram and result then
        result.ignore_global_max_size = true
        local original_render = result.render
        result.render = function(self, geometry)
          if self.window and vim.api.nvim_win_is_valid(self.window) then
            local info = vim.fn.getwininfo(self.window)[1]
            geometry = vim.tbl_extend("force", geometry or {}, {
              width = math.max(1, math.floor((info.width - info.textoff) * 0.9)),
              height = 0,
            })
          end
          return original_render(self, geometry)
        end
      end
      return result
    end
  end
end

require("diagram").setup({
  integrations = {
    markdown,
    require("diagram.integrations.neorg"),
  },
  renderer_options = {
    mermaid = {
      theme = "forest",
      scale = 3,
      width = 2400,
    },
    plantuml = {
      charset = "utf-8",
    },
    d2 = {
      theme_id = 1,
      scale = 3,
    },
    gnuplot = {
      theme = "dark",
      size = "2400,1500",
    },
  },
})
