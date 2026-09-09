local markdown = require("diagram.integrations.markdown")
markdown.filetypes = { "markdown", "vimwiki" }

require("diagram").setup({
  integrations = {
    markdown,
    require("diagram.integrations.neorg"),
  },
  renderer_options = {
    mermaid = {
      theme = "forest",
      scale = 2,
      width = 1600,
    },
    plantuml = {
      charset = "utf-8",
    },
    d2 = {
      theme_id = 1,
      scale = 2,
    },
    gnuplot = {
      theme = "dark",
      size = "1600,1000",
    },
  },
})
