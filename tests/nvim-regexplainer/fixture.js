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

/** practical examples */
/^@scope\/(.*)\.js";?$/;
/@scope\/(.*)\.(?:graphql|(?:t|j|cs)s)";?/;
/\.js";?/;
/js";?/;

/** errors */
/@scope\/(.*)\.{graphql,js,ts,css}/;

