use Test::More ;

use Test::Differences ;

plan tests => 2 ;

eq_or_diff "a", "a" ;

TODO: {
    local $TODO = "testing failure, not really a TODO" ;
    eq_or_diff "a", "b" ;
}
