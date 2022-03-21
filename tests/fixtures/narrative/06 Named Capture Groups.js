/**
 * capture group 1 (_optional_):
 *   `hello`
 * named capture group 2 `hello` (_>= 1x_):
 *   `world`
 * non-capturing group (_2-3x_):
 *   `one`
 */
/(hello)?(?<hello>world)+(?:one){2,3}/;

/**
 * capture group 1:
 *   One of `a-z`, or `a-z` (_2-5x_)
 * `a`
 * `-` (_optional_)
 * named capture group 2 `hello` (_4-5x_):
 *   `world`
 */
/([a-za-z]{2,5})a-?(?<hello>world){4,5}/g;

/**
 * capture group 1:
 *   One of `a-z`, or `a-z` (_2-5x_)
 * `-` (_optional_)
 * named capture group 2 `dolly`:
 *   **WB**
 *   **WORD**
 *   **0-9**
 *   **WS**
 *   **TAB**
 *   **LF**
 *   **CR**
 */
/([a-za-z]{2,5})-?(?<dolly>\b\w\d\s\t\n\r)/g;

