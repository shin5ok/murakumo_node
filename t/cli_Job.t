use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Job");

my $obj = Murakumo_Node::CLI::Job->new;

can_ok($obj, q{register});

done_testing();

