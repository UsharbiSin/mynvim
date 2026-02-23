require("img-clip").setup({
  default = {
    dir_path = ".markdown_images",
    file_name = "image_%Y-%m-%d_%H-%M-%S",
    -- 设为 false：粘贴时不再弹窗询问文件名，直接自动生成并插入
    prompt_for_file_name = false,
    -- 设为 false：粘贴完毕后光标保持在 Normal 模式
    insert_mode_after_paste = false,
    -- 设为体积更小的 avif 格式
    extension = 'avif',
    process_cmd = 'magick convert - -quality 75 avif:-'
  },

  filetypes = {
    vimwiki = {
      template = "![image<++>]($FILE_PATH)",
    },
    markdown = {
      template = "![image<++>]($FILE_PATH)",
    },
  },
})
