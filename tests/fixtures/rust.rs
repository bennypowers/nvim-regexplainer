use regex::Regex;

// `hello`
let _ = Regex::new(r"hello");

// **0-9** (_>= 1x_)
let _ = Regex::new(r"\d+");

// `hello`
// `.` (_optional_)
let _ = Regex::new(r"hello\.?");

// One of `a-z`, `A-Z`, or `0-9` (_6-12x_)
let _ = Regex::new(r"[a-zA-Z0-9]{6,12}");

// capture group 1:
//   `hello`
let _ = Regex::new(r"(hello)");

// named capture group 1 `name`:
//   `world`
let _ = Regex::new(r"(?<name>world)");

// Either `one`, `two`, or `three`
let _ = Regex::new(r"one|two|three");

// **START**
// `ok`
// **ANY** (_optional_)
// **END**
let _ = Regex::new(r"^ok.?$");

// **WB**
// **WORD**
// **0-9**
let _ = Regex::new(r"\b\w\d");

// `hello`
// non-capturing group:
//   `world`
let _ = Regex::new(r"hello(?:world)");
