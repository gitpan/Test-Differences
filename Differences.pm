package Test::Differences ;

=head1 NAME

Test::Differences - Test strings and data structures and show differences if not ok

=head1 SYNOPSIS

   use Test ;    ## Or use Test::More
   use Test::Differences ;

   eq_or_diff $got,  "a\nb\nc\n",   "testing strings" ;
   eq_or_diff \@got, [qw( a b c )], "testing arrays" ;

   ## Using with DBI-like data structures

   use DBI ;

   ... open connection & prepare statement and @expected_... here...
   
   eq_or_diff $sth->fetchall_arrayref, \@expected_arrays  "testing DBI arrays" ;
   eq_or_diff $sth->fetchall_hashref,  \@expected_hashes, "testing DBI hashes" ;

   ## To force textual or data line numbering (text lines are numbered 1..):
   eq_or_diff_text ... ;
   eq_or_diff_data ... ;

=head1 DESCRIPTION

When the code you're testing returns multiple lines or records and they're just
plain wrong, sometimes an equivalent to the Unix C<diff> utility is just what's
needed.

eq_or_diff_...() compares two strings or (limited) data structures and either
emits an ok indication (if they are equal) or calls a side-by-side diff (if
they differ) like:

    not ok 10
    # +-----+----------+
    # | Got | Expected |
    # +-----+----------+
    # > a   * b        <
    # +-----+----------+

These functions assume that you are presenting it with "flat" records, looking
like:

   - scalars composed of record-per-line
   - arrays of scalars,
   - arrays of arrays of scalars,
   - arrays of hashes containing only scalars

All of these are flattened in to single strings which are then compared for
differences.  Differently data structures can be compared, as long as they
flatten identically.

All other data structures are run through Data::Dumper first.  This is a bit
dangerous, as some version of perl shipped with Data::Dumpers that could do the
oddest things with some input.  This will be changed to an internal dumper with
good backward compatability when this bites somebody or I get some free time.

All nonprintable characters (including "\n" or "\r\n") are converted to an
escape code of some sort, since nonprinting characters can make identical
looking strings different.  This is especially true when comparing things on
platforms like Win32 where "\n" and "\r\n" usually look identical when C<perl>
prints them, and a text file missing "\n" on the last line can ruin your whole
day and make you go blind.  This can be a bit ugly, but, hey, these are failing
tests were talking about here, not hand-set epic poems.

C<eq_or_diff()> starts counting records at 0 unless you pass it two text
strings:

   eq_or_diff $a, $b ;   ## First line is line number 1
   eq_or_diff @a, @b ;   ## First element is element 0
   eq_or_diff $a, @b ;   ## First line/element is element 0

If you want to force a first record number of 0, use C<eq_or_diff_data>.  If
you want to force a first record number of 1, use C<eq_or_diff_text>.  I chose
this over passing in an options hash because it's clearer and simpler this way.
YMMV.

=head1 LIMITATIONS

This module "mixes in" with Test.pm or any of the test libraries based on
Test::Builder (Test::Simple, Test::More, etc).  It does this by 
peeking to see whether Test.pm or Test/Builder.pm is in %INC, so if you are
not using one of those, it will print a warning and play dumb by not emitting
test numbers (or incrementing them).  If you are using one of these, it
should interoperate nicely.

Uses Data::Dumper for complex data structures (like hashes :), which can lead
to some problems on older perls.

Exports all 3 functions by default (and by design).  Use

    use Test::Differences () ;

to suppress this behavior if you don't like the namespace pollution.

=cut

$VERSION = 0.2 ;

use Exporter ;

@ISA = qw( Exporter ) ;
@EXPORT = qw( eq_or_diff eq_or_diff_text eq_or_diff_data );

use strict ;

use Text::Diff ;
use Data::Dumper ;

sub _isnt_ARRAY_of_scalars {
    return 1 if ref ne "ARRAY" ;
    return scalar grep ref, @$_ ;
}


sub _isnt_HASH_of_scalars {
    return 1 if ref ne "HASH" ;
    return scalar grep ref, keys %$_ ;
}

use constant ARRAY_of_scalars => "ARRAY of scalars" ;
use constant ARRAY_of_ARRAYs_of_scalars => "ARRAY of ARRAYs of scalars" ;
use constant ARRAY_of_HASHes_of_scalars => "ARRAY of HASHes of scalars" ;


sub _grok_type {
    if ( ref eq "ARRAY" ) {
        return undef unless @$_ ;
        return ARRAY_of_scalars unless 
            _isnt_ARRAY_of_scalars ;
        return ARRAY_of_ARRAYs_of_scalars 
            unless grep _isnt_ARRAY_of_scalars, @$_ ;
        return ARRAY_of_HASHes_of_scalars
            unless grep _isnt_HASH_of_scalars, @$_ ;
        return "unknown" ;
    }
}


sub _decontrol {
    $_ =~ s/\n/\\n/g ;
    $_ =~ s/\r/\\r/g ;
    $_ =~ s/\t/\\t/g ;
    $_ =~ s{
            ([^[:print:]])
        }{
            my $codepoint = ord $1 ;
            $codepoint <= 0xFF
                ? sprintf "\0x%02x", $codepoint
                : sprintf "\0x{%04x}", $codepoint

        }ge ;

    $_ ;
}


## Flatten any acceptable data structure in to an array of lines.
sub _flatten {
    local $_ = shift if @_ ;

    return [ map _decontrol, split /^/m ] unless ref ;

    my $type = _grok_type ;

    if ( ! $type ) {
        local $Data::Dumper::Indent    = 1 ;
        local $Data::Dumper::SortKeys  = 1 ;
        local $Data::Dumper::Purity    = 0 ;
        local $Data::Dumper::Terse     = 1 ;
        local $Data::Dumper::DeepCopy  = 1 ;
        local $Data::Dumper::QuoteKeys = 0 ;
        return [ map { chomp ; _decontrol } split /^/, Dumper $_ ] ;
    }

    ## Copy the top level array so we don't trash the originals
    my @recs = @$_ ;

    if ( $type eq ARRAY_of_ARRAYs_of_scalars ) {
        ## Also copy the inner arrays if need be
        $_ = [ @$_ ] for @recs ;
    }


    if ( $type eq ARRAY_of_HASHes_of_scalars ) {
        my %headings ;
        for my $rec ( @recs ) {
            $headings{$_} = 1 for keys %$rec ;
        }
        my @headings = sort keys %headings ;

        ## Convert all hashes in to arrays.
        for my $rec ( @recs ) {
            $rec = [ map $rec->{$_}, @headings ],
        }

        unshift @recs, \@headings ;

        $type = ARRAY_of_ARRAYs_of_scalars ;
    }

    if ( $type eq ARRAY_of_ARRAYs_of_scalars ) {
        ## Convert undefs
        for my $rec ( @recs ) {
            for ( @$rec ) {
                $_ = "<undef>" unless defined ;
            }
        }
        
        ## Get widths of each column.
        my @widths ;
        my @ljusts  ;
        ## TODO: count decimal places for floats
        for my $rec ( @recs ) {
            for my $i ( 0..$#$rec ) {
                for ( $rec->[$i] ) {
                    $widths[$i] = length
                        if ! defined $widths[$i]
                        || length > $widths[$i] ;
                    $ljusts[$i] = 1
                        unless /^\d+/ ;
                    _decontrol ;
                }
            }
        }

        my @fmts ;
        for my $i ( 0..$#widths ) {
            push @fmts, join "",
                "%",
                $ljusts[$i] ? "-" : "",
                $widths[$i],
                "s" ;
        }

        for my $rec ( @recs ) {
            for my $i ( 0..$#$rec ) {
                $rec->[$i] = sprintf $fmts[$i], $rec->[$i] ;
            }
            $rec = join ",", @$rec ;
        }
    }

    return \@recs ;
}


sub _id_callers_test_package_of_choice {
    ## First see if %INC tells us much of interest.
    my $has_builder_pm = grep $_ eq "Test/Builder.pm", keys %INC;
    my $has_test_pm    = grep $_ eq "Test.pm",         keys %INC;

    return "Test"          if $has_test_pm && ! $has_builder_pm;
    return "Test::Builder" if ! $has_test_pm && $has_builder_pm;

    if ( $has_test_pm && $has_builder_pm ) {
        ## TODO: Look in caller's namespace for hints.  For now, assume Builder.
        ## This should only ever be an issue if multiple test suites end
        ## up in memory at once.
        return "Builder";
        
    }
}


my $warned_of_unknown_test_lib;

sub eq_or_diff_text { $_[3] = { data_type => "text" }; goto &eq_or_diff; }
sub eq_or_diff_data { $_[3] = { data_type => "data" }; goto &eq_or_diff; }

sub eq_or_diff {
    my ( @vals, $name, $options ) ;
    ( $vals[0], $vals[1], $name, $options ) = @_ ;

    my $data_type ;
    $data_type = $options->{data_type} if $options ;
    $data_type ||= "text" unless ref $vals[0] || ref $vals[1] ;
    $data_type ||= "data" ;

    my @widths ;

    @vals = map _flatten, @_[0,1] ;
    my $caller = caller ;

    my $passed = join( "", @{$vals[0]} ) eq join( "URK", @{$vals[1]} );

    my $diff;
    unless ( $passed ) {
        my $context = grep( @$_ > 25, @vals ) ? 3 : 25 ;
        $diff = diff @vals, {
            CONTEXT => $context,
            STYLE   => Test::Differences::SideBySide->new(
                LOCATORS => $context < 25,
                OFFSET   => $data_type eq "text" ? 1 : 0,
            ),
        } ;
        chomp $diff ;
        $diff .= "\n" ;
    }

    my $which = _id_callers_test_package_of_choice;

    if ( $which eq "Test" ) {
        @_ = $passed 
            ? ( "", "", $name )
            : ( "\n$diff", "No differences", $name );
        goto &Test::ok;
    }
    elsif ( $which eq "Test::Builder" ) {
        my $test = Test::Builder->new ;
        ## TODO: Call exported_to here?  May not need to because the caller
        ## should have imported something based on Test::Builder already.
        $test->ok( $passed, $name ) ;
        $test->diag( $diff ) unless $passed ;
    }
    else {
        unless ( $warned_of_unknown_test_lib ) {
            Carp::cluck
                "Can't identify test lib in use, doesn't seem to be Test.pm or Test::Builder based\n" ;
            $warned_of_unknown_test_lib = 1 ;
        }
        ## Play dumb and hope nobody notices the fool drooling in the corner
        if ( $passed ) {
            print "ok\n" ;
        }
        else {
            $diff =~ s/^/# /gm ;
            print "not ok\n", $diff ;
        }
    }
}


package Test::Differences::SideBySide ;

use vars qw( @ISA ) ;

@ISA = qw( Text::Diff::Base ) ;

sub new {
    my $proto = shift ;
    return bless { @_ }, $proto
}

## Old Text::Diffs doesn't export this
sub OPCODE() ;
*OPCODE = \&Text::Diff::OPCODE ;

sub hunk {
    my $self = shift ;
    pop ; # Ignore options
    my $ops = pop ;  ## Leave sequences in @_[0,1]

use Data::Dumper ; print Dumper $self ;

    ## Line numbers are one off, gotta bump them
    push @{$self->{LINES}}, [
        map( $_ + $self->{OFFSET}, @{$ops->[0]}[0,1]), "@"
    ] ;

    my ( @A, @B ) ;
    for ( @$ops ) {
        my $opcode = $_->[OPCODE] ;
        if ( $opcode eq " " ) {
            push @A, undef while @A < @B ;
            push @B, undef while @B < @A ;
        }
        if ( $opcode eq " " || $opcode eq "-" ) {
            push @A, $_[0]->[$_->[0]] ;
        }
        if ( $opcode eq " " || $opcode eq "+" ) {
            push @B, $_[1]->[$_->[1]] ;
        }
    }

    push @A, "" while @A < @B ;
    push @B, "" while @B < @A ;
    for ( 0..$#A ) {
        my ( $A, $B ) = (shift @A, shift @B ) ;
        push @{$self->{LINES}},
            [ $A, $B, 
                ! defined $A ? "-" :
                ! defined $B ? "+" :
                $A eq $B ? " " : "X"
            ] ;
    }
}


sub file_footer {
    my $self = shift ;

    my $a_width = length "Got" ;
    my $b_width = length "Expected" ;
    for ( @{$self->{LINES}} ) {
        $a_width = length $_->[0]
            if defined $_->[0] && length $_->[0] > $a_width ;
        $b_width = length $_->[1]
            if defined $_->[1] && length $_->[1] > $b_width ;
    }

    my %fmts = (
        " " => "| %-${a_width}s | %-${b_width}s |\n",
        "@" => "@%-${a_width}d  @%-${b_width}d  @\n",
        "X" => "> %-${a_width}s * %-${b_width}s <\n",
        "-" => "> %-${a_width}s *" . ( "x" x ( $b_width + 2 ) ) . "<\n",
        "+" => ">" . ( "x" x ( $a_width + 2 ) ) . "* %-${b_width}s <\n",
    ) ;

    my $bar     = join "",
        "+",
        ( "-" x  ( $a_width + 2 ) ),
        "+",
        ( "-" x  ( $b_width + 2 ) ),
        "+\n" ;

    return join( "",
        $bar,
        sprintf( $fmts{" "}, "Got", "Expected" ),
        $bar,
        map(
            sprintf( $fmts{$_->[2]}, @$_[0,1] ),
            grep $self->{LOCATORS} || $_->[2] ne "@",
            @{$self->{LINES}}
        ),
        $bar
    ) ;
}

=head1 AUTHOR

    Barrie Slaymaker <barries@slaysys.com>

=head1 LICENSE

Copyright 2001 Barrie Slaymaker, All Rights Reserved.

You may use this software under the terms of the GNU public license, any
version, or the Artistic license.

=cut


1 ;
