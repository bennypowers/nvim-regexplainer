(comment) @test.comment
(call_expression
  function: (selector_expression
    operand: (identifier) @_pkg)
  arguments: (argument_list .
    (raw_string_literal
      (raw_string_literal_content) @test.pattern))
  (#eq? @_pkg "regexp"))
