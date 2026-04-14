(line_comment) @test.comment
(call_expression
  function: (scoped_identifier
    path: (identifier) @_type)
  arguments: (arguments .
    (raw_string_literal
      (string_content) @test.pattern))
  (#eq? @_type "Regex"))
