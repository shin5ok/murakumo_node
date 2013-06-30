use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Libvirt");

my $obj = Murakumo_Node::CLI::Libvirt->new;

can_ok($obj, q{conn});

done_testing();



