use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Mail_API");

my $obj = Murakumo_Node::CLI::Mail_API->new;

can_ok($obj, q{post});

done_testing();



