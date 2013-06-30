use strict;
use warnings;
use Test::More;

require_ok("Murakumo_Node::CLI::Libvirt::XML");

my $obj = Murakumo_Node::CLI::Libvirt::XML->new;

my @methods = qw(
  create_interface_xml
  create_disk_xml
  create_vps_xml
  create_storage_xml
  create_iface_for_libvirt
);
can_ok($obj, @methods);

done_testing();


