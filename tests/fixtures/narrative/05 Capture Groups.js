/** 
 * `@`
 * capture group 1:
 *   `hello`
 */
/@(hello)/;

/**
 * `@`
 * capture group 1:
 *   `hello`
 * capture group 2:
 *   `world`
 */
/@(hello)(world)/;

/**
 * `zero`
 * capture group 1:
 *   `one`
 *   capture group 2:
 *     `two`
 *     capture group 3:
 *       `three`
 */
/zero(one(two(three)))/;

/**
 * `@`
 * capture group 1:
 *   **WB**
 *   **WORD**
 *   **0-9**
 *   **WS**
 *   **TAB**
 *   **LF**
 *   **CR**
 */
/@(\b\w\d\s\t\n\r)/g;

/**
 * `@`
 * capture group 1:
 *   `a1`
 *   **0-9**
 */
/@(a1\d)/g;

