; Pattern.compile("...")
(method_invocation
  object: (identifier) @_class
  name: (identifier) @_method
  arguments: (argument_list .
    (string_literal) @regexplainer.string_pattern)
  (#eq? @_class "Pattern")
  (#eq? @_method "compile"))

; Pattern.matches("...", input)
(method_invocation
  object: (identifier) @_class
  name: (identifier) @_method
  arguments: (argument_list .
    (string_literal) @regexplainer.string_pattern)
  (#eq? @_class "Pattern")
  (#eq? @_method "matches"))

; String.matches / String.replaceAll / String.replaceFirst / String.split
(method_invocation
  name: (identifier) @_method
  arguments: (argument_list .
    (string_literal) @regexplainer.string_pattern)
  (#any-of? @_method "matches" "replaceAll" "replaceFirst" "split"))
