use strict;
use warnings;
use Test::More;
use JSON;
use URI;


use Catalyst::Test 'Murakumo_Node';
use Murakumo_Node::Controller::Node;

SKIP: {
  subtest "api /node/setup_node" => sub {
    ok 1;
  };
}

done_testing();
