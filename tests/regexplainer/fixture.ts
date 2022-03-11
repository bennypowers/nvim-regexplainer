/** simple */
/hello/;

/** modifiers and escape chars */
/hello!?/; 
/hello\.?/;

/** special characters */
/^ok.?$/;
/\b\w\d\s\t\n\r/;

/** ranges and quantifiers */
/@hello[a-z]/;
/a{1}b{2,}c{3,5}d*e+/g;
/\b[a-z0-9._%+-]+@hello[a-z0-9.-]+\.[a-z]{2,}\b/;
/[\w\b\d\s\t\n\r]/;
/^[a-zA-Z0-9]{6,12}$/;

/** Negated range */
/^p[^p^a]*p/;

/** capture group */
/(hello)/;
/(hello)(world)/;
/zero(one(two(three)))/;
/(\w\d\s\t\n\r)/g;
/(a1\d)/g;

/** named capture group */
/(hello)?(?<hello>world)+(?:one){2,3}/;
/([a-za-z]{2,5})a-?(?<hello>world){4,5}/g;
/([a-za-z]{2,5})-?(?<dolly>\w\d\s\t\n\r)/g;

/** non capturing group */
/hello(?:world|dolly)/;

/** alternations */
/\b|\w|\d|\s|\t|\n|\r/g;
/one|two/;
/one|two|three/;
/(one|two|three)/;
/zero|bupkis|gornisht|(one|two|three|(four|five))/;

/** lookahead */
/@(?=u)@/;
/@(?!u)@/;
/@(?=up|down){2,3}@/;
/@(?![\w\s])@/;
/@(?=g(?:raph)?ql)@/;

/** lookbehind */
/(?<=it's the )attack of the killer tomatos/;
/x(?<!u)@/;
/x(?<=a|b)y/;
/x(?<![\w\s])@/;
/(?<=g(?:raph)?ql)@/;

/** practical examples */
/^@scope\/(.*)\.js";?$/;
/@scope\/(.*)\.(?<extension>graphql|(?:t|j|cs)s)";?/;

/** errors */
/@scope\/(.*)\.{graphql,js,ts,css}/;

