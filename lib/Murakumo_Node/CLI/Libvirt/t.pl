use strict;
use warnings;
use Data::Dumper;
use lib qw(/home/kawano/Murakumo_Node/lib);

use Murakumo_Node::CLI::Libvirt::XML;

my $x = Murakumo_Node::CLI::Libvirt::XML->new;

my @interfaces;
my @disks;
{
  my $r = {
    mac => '00:11:cc:33:55:77',
    bridge => 'br0200',
    driver => 'virtio',
    ip     => '1.3.8.10',
  };
  
  my $xml_data = $x->create_interface_xml( $r );
  
  push @interfaces, $xml_data;
}
print "---------------\n";
{
  my $r = {
    image_path => '/vm/111/v10001.img',
    devname    => 'vda',
  };
  
  my $xml_data = $x->create_disk_xml( $r );
  
  print $xml_data;
  push @disks, $xml_data;
}
print "---------------\n";
{

  chomp ( my $uuid = `uuidgen` );

  my $r = {
    name => $uuid,
    uuid => $uuid,
    memory => 1024000,
    cpu    => 2,
    clock  => 'utc',
    # interface => [ $nw_ref, ],
    # disks  => [ $disk_ref, ],

  };
  
  my $xml_data = $x->create_vps_xml( $r, \@disks, \@interfaces, );
  
  print $xml_data. "\n";
}
