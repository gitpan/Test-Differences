use Test ;

use Test::Differences ;

my @tests = (
sub { eq_or_diff "a", "a" },
sub { eq_or_diff "a", "b" },
sub { eq_or_diff "a\nb\nc\n", "a\nc\n" },
sub { eq_or_diff "a\nb\nc\n", "a\nB\nc\n" },
sub { eq_or_diff "a\nb\nc\nd\ne\n", "a\nc\ne\n" },
) ;

plan tests => scalar @tests, todo => [2,3,4,5] ;

print "# This test misuses TODO: these TODOs are actually real tests.\n";

$_->() for @tests ;
