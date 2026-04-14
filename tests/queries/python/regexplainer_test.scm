(comment) @test.comment
(expression_statement
  (call
    function: (attribute
      object: (identifier) @_mod)
    arguments: (argument_list .
      (string
        (string_content) @test.pattern)))
  (#eq? @_mod "re"))
