#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Catalyst::Test 'Murakumo_Node';

ok( request('/check')->is_success, 'Request should succeed' );

done_testing();
