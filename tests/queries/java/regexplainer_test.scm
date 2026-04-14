(line_comment) @test.comment
(method_invocation
  object: (identifier) @_class
  name: (identifier) @_method
  arguments: (argument_list .
    (string_literal) @test.pattern)
  (#eq? @_class "Pattern")
  (#eq? @_method "compile"))
