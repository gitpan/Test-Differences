use Test ;

use Test::Differences ;

sub d($) {
    return Test::Differences::_escape(shift);
}

my @tests = (
sub { ok d chr   0x00,     "\\x00" },
sub { ok d chr   0x01,      "\\cA" },
sub { ok d       "\n",       "\\n" },
sub { ok d       "\r",       "\\r" },
sub { ok d       "\t",       "\\t" },
sub { ok d chr   0x1f,     "\\x1f" },
sub { ok d        " ",         " " },
sub { ok d        "a",         "a" },
sub { ok d        "_",         "_" },
sub { ok d chr   0x80,     "\\x80" },
sub { ok d chr   0xff,     "\\xff" },
## Testing > 0xff is hard on various perls
##sub { ok d chr  0x100, "\\x{0100}" },
##sub { ok d chr 0xffff, "\\x{ffff}" },
) ;

plan tests => scalar @tests ;

$_->() for @tests ;
