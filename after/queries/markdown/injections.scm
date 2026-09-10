; extends

((fenced_code_block
  (info_string
    (language) @_language)
  (code_fence_content) @injection.content)
  (#eq? @_language "c++")
  (#set! injection.language "cpp"))
