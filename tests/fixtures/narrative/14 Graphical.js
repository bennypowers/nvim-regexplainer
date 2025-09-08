/**
 * `a`
 */
/a/;

/**
 * `Hello`
 */
/Hello/;

/**
 * `1`
 */
/\1/;

/**
 * `1`
 */
/1/;

/**
 * `123`
 */
/123/;

/**
 * `123`
 */
/\1\2\3/;

/**
 * Character classes
 */
/[abc]/;

/**
 * Negated character class
 */
/[^0-9]/;

/**
 * Word boundaries
 */
/\bword\b/;

/**
 * Simple quantifiers
 */
/ab+c*/;

/**
 * Optional pattern
 */
/colou?r/;

/**
 * Simple alternation
 */
/cat|dog/;

/**
 * Basic capturing group
 */
/(hello)/;

/**
 * Nested groups
 */
/(a(b|c)d)/;

/**
 * Email pattern - basic
 */
/\w+@\w+\.\w+/;

/**
 * Phone number pattern
 */
/\(\d{3}\)\s\d{3}-\d{4}/;

/**
 * URL pattern - simplified
 */
/https?:\/\/[\w.-]+\/?\w*/;

/**
 * Complex alternation with groups
 */
/(Mr|Mrs|Ms|Dr)\.?\s([A-Z][a-z]+)/;

/**
 * Advanced quantifiers
 */
/\d{2,4}-\d{2}-\d{2}/;

/**
 * Lookahead assertion
 */
/\d+(?=\s*dollars?)/;

/**
 * Lookbehind assertion
 */
/(?<=\$)\d+(\.\d{2})?/;

/**
 * Complex email validation
 */
/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
