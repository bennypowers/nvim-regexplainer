import java.util.regex.Pattern;

// `hello`
Pattern.compile("hello");

// **0-9** (_>= 1x_)
Pattern.compile("\\d+");

// `hello`
// `.` (_optional_)
Pattern.compile("hello\\.?");

// One of `a-z`, `A-Z`, or `0-9` (_6-12x_)
Pattern.compile("[a-zA-Z0-9]{6,12}");

// capture group 1:
//   `hello`
Pattern.compile("(hello)");

// named capture group 1 `name`:
//   `world`
Pattern.compile("(?<name>world)");

// Either `one`, `two`, or `three`
Pattern.compile("one|two|three");

// **START**
// `ok`
// **ANY** (_optional_)
// **END**
Pattern.compile("^ok.?$");

// **WB**
// **WORD**
// **0-9**
Pattern.compile("\\b\\w\\d");

// `hello`
// non-capturing group:
//   `world`
Pattern.compile("hello(?:world)");
