/**
 * `@` **followed by **:
 *   `u`
 * `@`
 */
/@(?=u)@/;

/**
 * `@` **NOT followed by **:
 *   `u`
 * `@`
 */
/@(?!u)@/;

/**
 * `@` **followed by ** (_2-3x_):
 *   Either `up` or `down`
 * `@`
 */
/@(?=up|down){2,3}@/;

/**
 * `@` **NOT followed by **:
 *   One of **WORD**, or **WS**
 * `@`
 */
/@(?![\w\s])@/;

/**
 * `@` **followed by **:
 *   `g`
 *   non-capturing group (_optional_):
 *     `raph`
 *   `ql`
 * `@`
 */
/@(?=g(?:raph)?ql)@/;

/**
 * **preceeding **:
 *   `it's the `
 * `attack of the killer tomatos`
 */
/(?<=it's the )attack of the killer tomatos/;

/**
 * `x` **NOT preceeding **:
 *   `u`
 * `@`
 */
/x(?<!u)@/;

// UNSUPPORTED
// /x(?<=a|b)y/;
// /x(?<![\w\s])@/;


/**
 * **preceeding **:
 *   `g`
 * `\``
 * capture group 1:
 *   **ANY** (_>= 0x_)
 * `\``
 */
/(?<=g)`(.*)`/mg;

/**
 * **preceeding **:
 *   `g`
 *   non-capturing group (_optional_):
 *     `raph`
 *   `ql`
 * `\``
 * capture group 1:
 *   **ANY** (_>= 0x_)
 * `\``
 */
/(?<=g(?:raph)?ql)`(.*)`/mg;


