use strict;
use warnings;
use Test::More;
use JSON;
use URI;


use Catalyst::Test 'Murakumo_Node';
use Murakumo_Node::Controller::Node;

subtest "api /check" => sub {

  my ($r, $c) = ctx_request("/check");

  diag $r->content;
  ok($r->is_success);

};

done_testing();
