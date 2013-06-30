use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::VPS");

my $obj = Murakumo_Node::CLI::VPS->new;

my @methods = qw(
  domain_obj
  make_bridge_and_storage_pool
  boot2
  shutdown
  terminate
  get_xml_ref
  is_active
  operation
  clone
  migration

);

can_ok($obj, @methods);

done_testing();

