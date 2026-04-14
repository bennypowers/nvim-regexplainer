package main

import "regexp"

// `hello`
var _ = regexp.MustCompile(`hello`)

// **0-9** (_>= 1x_)
var _ = regexp.MustCompile(`\d+`)

// `hello`
// `.` (_optional_)
var _ = regexp.MustCompile(`hello\.?`)

// One of `a-z`, `A-Z`, or `0-9` (_6-12x_)
var _ = regexp.MustCompile(`[a-zA-Z0-9]{6,12}`)

// capture group 1:
//   `hello`
var _ = regexp.MustCompile(`(hello)`)

// named capture group 1 `name`:
//   `world`
var _ = regexp.MustCompile(`(?<name>world)`)

// Either `one`, `two`, or `three`
var _ = regexp.MustCompile(`one|two|three`)

// **START**
// `ok`
// **ANY** (_optional_)
// **END**
var _ = regexp.MustCompile(`^ok.?$`)

// **WB**
// **WORD**
// **0-9**
var _ = regexp.MustCompile(`\b\w\d`)

// `hello`
// non-capturing group:
//   `world`
var _ = regexp.MustCompile(`hello(?:world)`)
