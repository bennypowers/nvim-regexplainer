; raw string in re.* calls
(call
  function: (attribute
    object: (identifier) @_module
    attribute: (identifier))
  arguments: (argument_list .
    (string
      (string_start) @_start
      (string_content) @regexplainer.pattern)
    (#lua-match? @_start "^[rR]"))
  (#eq? @_module "re"))

; non-raw string in re.* calls
(call
  function: (attribute
    object: (identifier) @_module
    attribute: (identifier))
  arguments: (argument_list .
    (string
      (string_start) @_start
      (string_content) @regexplainer.string_pattern)
    (#not-lua-match? @_start "^[rR]"))
  (#eq? @_module "re"))
