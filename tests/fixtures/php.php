<?php

// `hello`
preg_match('/hello/', $s);

// **0-9** (_>= 1x_)
preg_match('/\d+/', $s);

// `hello`
// `.` (_optional_)
preg_match('/hello\.?/', $s);

// One of `a-z`, `A-Z`, or `0-9` (_6-12x_)
preg_match('/[a-zA-Z0-9]{6,12}/', $s);

// capture group 1:
//   `hello`
preg_match('/(hello)/', $s);

// named capture group 1 `name`:
//   `world`
preg_match('/(?<name>world)/', $s);

// Either `one`, `two`, or `three`
preg_match('/one|two|three/', $s);

// **START**
// `ok`
// **ANY** (_optional_)
// **END**
preg_match('/^ok.?$/', $s);

// **WB**
// **WORD**
// **0-9**
preg_match('/\b\w\d/', $s);

// `hello`
// non-capturing group:
//   `world`
preg_match('/hello(?:world)/', $s);
