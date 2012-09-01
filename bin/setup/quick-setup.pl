#!/usr/bin/murakumo-perl
use strict;
use warnings;
use Carp;

no strict 'refs';

system_env_check();
my $n = 1;
for my $x ( get_params() ) {
  printf "%s > \n", $x->{comment};
  INPUT:
  while (1) {
    chomp ( my $input = <STDIN> );
    if ( $input !~ /$x->{input_regex}/ ) {
      print "input value is invalid...\n";
      next INPUT;
    }
  }
  $x->{__input} = $input;
}



sub get_params {
[
  {
    comment     => "",
    input_regex => "",
    name        => "",
  },
  {
    comment     => "",
    input_regex => "",
    name        => "",
  },
  {
    comment     => "",
    input_regex => "",
    name        => "",
  },
]
}

sub system_env_check {

}

