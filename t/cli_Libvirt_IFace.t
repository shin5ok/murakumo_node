use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Libvirt::IFace");

my $obj = Murakumo_Node::CLI::Libvirt::IFace->new;

can_ok($obj, q{make_br_and_vlan});

done_testing();
