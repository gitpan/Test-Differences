use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => "Test::Differences",
#    PMLIBDIRS    => [ 'Run' ],
    VERSION_FROM  => "Differences.pm",
);


sub MY::libscan {
   package MY ;
   my $self = shift ;
   my ( $path ) = @_ ;
   return '' if /\.sw[a-z]$/ ;
   return '' unless length $self->SUPER::libscan( $path ) ;
   return $path ;
}
