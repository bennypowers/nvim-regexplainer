# `hello`
x = /hello/

# **0-9** (_>= 1x_)
x = /\d+/

# `hello`
# `.` (_optional_)
x = /hello\.?/

# One of `a-z`, `A-Z`, or `0-9` (_6-12x_)
x = /[a-zA-Z0-9]{6,12}/

# capture group 1:
#   `hello`
x = /(hello)/

# named capture group 1 `name`:
#   `world`
x = /(?<name>world)/

# Either `one`, `two`, or `three`
x = /one|two|three/

# **START**
# `ok`
# **ANY** (_optional_)
# **END**
x = /^ok.?$/

# **WB**
# **WORD**
# **0-9**
x = /\b\w\d/

# `hello`
# non-capturing group:
#   `world`
x = /hello(?:world)/
