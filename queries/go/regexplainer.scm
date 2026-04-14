; raw string (backtick) in regexp.Compile / regexp.MustCompile
(call_expression
  function: (selector_expression
    operand: (identifier) @_pkg
    field: (field_identifier) @_func)
  arguments: (argument_list .
    (raw_string_literal
      (raw_string_literal_content) @regexplainer.pattern))
  (#eq? @_pkg "regexp")
  (#any-of? @_func "Compile" "MustCompile" "CompilePOSIX" "MustCompilePOSIX"))

; interpreted string in regexp.Compile / regexp.MustCompile
(call_expression
  function: (selector_expression
    operand: (identifier) @_pkg
    field: (field_identifier) @_func)
  arguments: (argument_list .
    (interpreted_string_literal) @regexplainer.string_pattern)
  (#eq? @_pkg "regexp")
  (#any-of? @_func "Compile" "MustCompile" "CompilePOSIX" "MustCompilePOSIX"))
