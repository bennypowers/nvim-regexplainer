; string in preg_* calls
(function_call_expression
  function: (name) @_func
  arguments: (arguments .
    (argument
      (string
        (string_content) @regexplainer.delimited_pattern)))
  (#any-of? @_func
    "preg_match" "preg_match_all" "preg_replace"
    "preg_replace_callback" "preg_split" "preg_grep"
    "preg_filter" "preg_quote"))
