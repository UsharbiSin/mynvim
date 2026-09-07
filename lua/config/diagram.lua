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
    },
    plantuml = {
      charset = "utf-8",
    },
    d2 = {
      theme_id = 1,
    },
    gnuplot = {
      theme = "dark",
      size = "800,600",
    },
  },
})
