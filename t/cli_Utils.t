use strict;
use warnings;
use Test::More;

BEGIN {
  use_ok("Murakumo_Node::CLI::Utils");
};

my @functions = qw(
  critical
  command
  remove_set
  is_debug
  dumper
  logging
);

can_ok("main", @functions);

my $obj = Murakumo_Node::CLI::Utils->new;

my @methods = qw(
  config
  create_random_mac
  critical
  command
  get_api_key
  logging
  remove_set
);

can_ok($obj, @methods);

my $like_mac = qr/^
                   [0-9a-f]{2}:
                   [0-9a-f]{2}:
                   [0-9a-f]{2}:
                   [0-9a-f]{2}:
                   [0-9a-f]{2}:
                   [0-9a-f]{2}
              $/xms;

like( $obj->create_random_mac, $like_mac, "mac address create");

done_testing();

