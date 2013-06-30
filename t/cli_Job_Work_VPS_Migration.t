use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Job::Work::VPS::Migration");
can_ok( q{Murakumo_Node::CLI::Job::Work::VPS::Migration}, q{work} );

done_testing();
