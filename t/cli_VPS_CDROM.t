use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::VPS::CDROM");

my $obj = Murakumo_Node::CLI::VPS::CDROM->new;

can_ok($obj, q{change});

done_testing();

