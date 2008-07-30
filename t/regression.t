
use Test;

use Test::Differences;

my $got = [
    { a => 1 },
    {   b => 1,
        c => [],
    }
];
my $expected = [
    { a => 1 },
    {   b => 1,
        c => [],
    }
];

my @tests = (
    sub { eq_or_diff $got, $expected },
);

plan tests => scalar @tests;

$_->() for @tests;
