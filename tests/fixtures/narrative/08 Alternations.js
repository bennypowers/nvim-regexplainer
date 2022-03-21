/**
 * Either **WB**, **WORD**, **0-9**, **WS**, **TAB**, **LF**, or **CR**
 */
/\b|\w|\d|\s|\t|\n|\r/g;

/**
 * Either `one` or `two`
 */
/one|two/;

/**
 * Either `one`, `two`, or `three`
 */
/one|two|three/;

/**
 * capture group 1:
 *   Either `one`, `two`, or `three`
 */
/(one|two|three)/;

/**
 * Either `zero`, `bupkis`, `gornisht`, or capture group 1:
 *   Either `one`, `two`, `three`, or capture group 2:
 *     Either `four` or `five`
 */
/zero|bupkis|gornisht|(one|two|three|(four|five))/;

/**
 * `"`
 * capture group 1:
 *   Either `http` or capture group 2:
 *     `cs`
 *   `s`
 * `"`
 * `;` (_optional_)
 */
/"(http|(cs)s)";?/;

