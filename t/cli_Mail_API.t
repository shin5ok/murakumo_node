use strict;
use warnings;
use Test::More;
use Sys::Hostname;

require_ok("Murakumo_Node::CLI::Mail_API");

my $obj = Murakumo_Node::CLI::Mail_API->new( q{postmaster@} . hostname );

can_ok($obj, q{post});

done_testing();



