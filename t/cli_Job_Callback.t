use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Job::Callback");

my $obj = Murakumo_Node::CLI::Job::Callback->new({ params => {} });

my @methods = qw(
  uri
  set_params
  set_result
  set_ok
  call
  is_called
);

can_ok($obj, @methods);

done_testing();

