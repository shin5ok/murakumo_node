use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Job::Work::VPS::Shutdown");
can_ok( q{Murakumo_Node::CLI::Job::Work::VPS::Shutdown}, q{work} );

done_testing();

