use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::VPS::Migration");

my $obj = Murakumo_Node::CLI::VPS::Migration->new;

can_ok($obj, q{run});

done_testing();
