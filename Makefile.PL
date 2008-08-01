use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Test::Differences',
    AUTHOR              => 'Curtis "Ovid" Poe <ovid@cpan.org>',
    VERSION_FROM        => 'lib/Test/Differences.pm',
    ABSTRACT_FROM       => 'lib/Test/Differences.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Text::Diff' => 0.35,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Test-Differences-*' },
);
