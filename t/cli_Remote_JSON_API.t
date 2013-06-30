use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Remote_JSON_API");

my $obj = Murakumo_Node::CLI::Remote_JSON_API->new;

my @methods = qw(
  post
  query
  get
  json_post
);
can_ok($obj, @methods);

done_testing();

