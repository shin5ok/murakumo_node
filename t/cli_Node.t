use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Node");

my $obj = Murakumo_Node::CLI::Node->new;

my @methods = qw(
  list_vps_ids
  list_vps_uuids
);
can_ok($obj, @methods);

done_testing();




