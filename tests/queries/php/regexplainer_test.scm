(comment) @test.comment
(function_call_expression
  function: (name) @_func
  arguments: (arguments .
    (argument
      (string
        (string_content) @test.pattern)))
  (#any-of? @_func "preg_match" "preg_match_all" "preg_replace" "preg_split"))
