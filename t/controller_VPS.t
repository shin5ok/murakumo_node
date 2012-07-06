use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Murakumo_Node';
use Murakumo_Node::Controller::VPS;

ok( request('/vps')->is_success, 'Request should succeed' );
done_testing();
