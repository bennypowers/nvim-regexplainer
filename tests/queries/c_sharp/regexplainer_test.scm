(comment) @test.comment
(object_creation_expression
  type: (identifier) @_type
  arguments: (argument_list .
    (argument
      (verbatim_string_literal) @test.pattern))
  (#eq? @_type "Regex"))
