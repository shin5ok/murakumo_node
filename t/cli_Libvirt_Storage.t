use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Libvirt::Storage");

my $obj = Murakumo_Node::CLI::Libvirt::Storage->new;

my @methods = qw(
  del
  is_mounted_storage
  add_by_path
  add
  mount_nfs_storage
  umount_nfs_storage
);
can_ok($obj, @methods);

done_testing();

