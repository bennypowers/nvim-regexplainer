import re

# `hello`
re.compile(r"hello")

# **0-9** (_>= 1x_)
re.compile(r"\d+")

# `hello`
# `.` (_optional_)
re.compile(r"hello\.?")

# One of `a-z`, `A-Z`, or `0-9` (_6-12x_)
re.compile(r"[a-zA-Z0-9]{6,12}")

# capture group 1:
#   `hello`
re.compile(r"(hello)")

# named capture group 1 `name`:
#   `world`
re.compile(r"(?<name>world)")

# Either `one`, `two`, or `three`
re.compile(r"one|two|three")

# **START**
# `ok`
# **ANY** (_optional_)
# **END**
re.compile(r"^ok.?$")

# **WB**
# **WORD**
# **0-9**
re.compile(r"\b\w\d")

# `hello`
# non-capturing group:
#   `world`
re.compile(r"hello(?:world)")
