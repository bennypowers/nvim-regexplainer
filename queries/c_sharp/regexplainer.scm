; new Regex("...") or new Regex(@"...")
(object_creation_expression
  type: (identifier) @_type
  arguments: (argument_list .
    (argument
      [(string_literal) @regexplainer.string_pattern
       (verbatim_string_literal) @regexplainer.string_pattern]))
  (#eq? @_type "Regex"))

; Regex.IsMatch / Regex.Match / Regex.Matches / Regex.Replace / Regex.Split
(invocation_expression
  function: (member_access_expression
    expression: (identifier) @_type
    name: (identifier) @_method)
  arguments: (argument_list
    (argument
      [(string_literal) @regexplainer.string_pattern
       (verbatim_string_literal) @regexplainer.string_pattern]))
  (#eq? @_type "Regex")
  (#any-of? @_method "IsMatch" "Match" "Matches" "Replace" "Split"))
