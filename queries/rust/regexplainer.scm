; raw string in Regex::new
(call_expression
  function: (scoped_identifier
    path: (identifier) @_type
    name: (identifier) @_func)
  arguments: (arguments .
    (raw_string_literal
      (string_content) @regexplainer.pattern))
  (#eq? @_type "Regex")
  (#eq? @_func "new"))

; regular string in Regex::new
(call_expression
  function: (scoped_identifier
    path: (identifier) @_type
    name: (identifier) @_func)
  arguments: (arguments .
    (string_literal) @regexplainer.string_pattern)
  (#eq? @_type "Regex")
  (#eq? @_func "new"))

; RegexBuilder::new
(call_expression
  function: (scoped_identifier
    path: (identifier) @_type
    name: (identifier) @_func)
  arguments: (arguments .
    [(raw_string_literal
       (string_content) @regexplainer.pattern)
     (string_literal) @regexplainer.string_pattern])
  (#eq? @_type "RegexBuilder")
  (#eq? @_func "new"))
