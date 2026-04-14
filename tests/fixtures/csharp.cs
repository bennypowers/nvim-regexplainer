using System.Text.RegularExpressions;

// `hello`
var r = new Regex(@"hello");

// **0-9** (_>= 1x_)
var r = new Regex(@"\d+");

// `hello`
// `.` (_optional_)
var r = new Regex(@"hello\.?");

// One of `a-z`, `A-Z`, or `0-9` (_6-12x_)
var r = new Regex(@"[a-zA-Z0-9]{6,12}");

// capture group 1:
//   `hello`
var r = new Regex(@"(hello)");

// named capture group 1 `name`:
//   `world`
var r = new Regex(@"(?<name>world)");

// Either `one`, `two`, or `three`
var r = new Regex(@"one|two|three");

// **START**
// `ok`
// **ANY** (_optional_)
// **END**
var r = new Regex(@"^ok.?$");

// **WB**
// **WORD**
// **0-9**
var r = new Regex(@"\b\w\d");

// `hello`
// non-capturing group:
//   `world`
var r = new Regex(@"hello(?:world)");
