use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Guestfs");
use_ok("Murakumo_Node::CLI::Utils");

my $config = Murakumo_Node::CLI::Utils->config;

my $obj = Murakumo_Node::CLI::Guestfs->new( $config->{guestfs_script_path} );
ok($obj, "guestfs object");

can_ok($obj, q{set_network});
done_testing();

