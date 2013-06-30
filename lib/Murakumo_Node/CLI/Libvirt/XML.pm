use warnings;
use strict;
use 5.014;

package Murakumo_Node::CLI::Libvirt::XML 0.01;

use Carp;
use Data::Dumper;
use Try::Tiny;
use Carp;
use Template;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;

sub new {
  my $class  = shift;
  my $tt     = Template->new( ABSOLUTE => 1 );
  my $config = Murakumo_Node::CLI::Utils->new->config;
  my $obj    = bless {
                 tt     => $tt,
                 config => $config,
               }, $class;

  $obj->{xml_template_dir_path} = sprintf "%s/%s",
                                          $config->{module_root},
                                          $config->{template_dir_path};
  return $obj;
}

sub create_interface_xml {
  my ($self, $p) = @_;
  no strict 'refs';

  # nw.tt
  # [% mac -%]
  # [% bridge -%]
  # [% driver -%]
  # [% ip -%]
  my $config  = $self->{config};
  my $tt_path = sprintf "%s/%s", $self->{xml_template_dir_path}, $config->{nw_xml_template_name};
  -f $tt_path
    or croak "*** $tt_path is not found";

  my $xml_data = qq{};
  $self->{tt}->process( $tt_path, $p, \$xml_data );

  return $xml_data;

}

sub create_disk_xml {
  my ($self, $p) = @_;
  no strict 'refs';

  # disk.tt
  # [% image_path -%]
  # [% devname -%]
  # [% driver -%]
  my $config  = $self->{config};
  my $tt_path = sprintf "%s/%s", $self->{xml_template_dir_path}, $config->{disk_xml_template_name};
  -f $tt_path
    or croak "*** $tt_path is not found";

  my $xml_data = qq{};
  $self->{tt}->process( $tt_path, $p, \$xml_data );

  return $xml_data;

}

sub create_vps_xml {
  my ($self, $p, $disk_array_ref, $if_array_ref) = @_;
  no strict 'refs';

  # vps.tt
  # [% name -%]
  # [% uuid -%]
  # [% memory -%]
  # [% cpu -%]
  # [% clock -%]
  # [% FOREACH disk = disks -%]
  # [% disk -%]
  # [% FOREACH interface = interfaces -%]
  # [% interface -%]

  $p->{disks}      = $disk_array_ref;
  $p->{interfaces} = $if_array_ref;

  my $config  = $self->{config};
  my $tt_path = sprintf "%s/%s", $self->{xml_template_dir_path}, $config->{vps_xml_template_name};
  -f $tt_path
    or croak "*** $tt_path is not found";

  my $xml_data = qq{};
  $self->{tt}->process( $tt_path, $p, \$xml_data );

  return $xml_data;

}

sub create_storage_xml {
  my ($self, $p) = @_;

  my $config  = $self->{config};

  my $tt_path = sprintf "%s/%s", $self->{xml_template_dir_path}, $config->{storage_xml_template_name};
  -f $tt_path
    or croak "*** $tt_path is not found";

  my $xml_data = qq{};
  $self->{tt}->process( $tt_path, $p, \$xml_data );

  return $xml_data;

}

sub create_iface_for_libvirt {
  my ($self, $p) = @_;

  # <interface type='bridge' name='br0-102'>
  #   <protocol family='ipv6'>
  #     <ip address='fe80::7a2b:cbff:fe27:efe6' prefix='64'/>
  #   </protocol>
  #   <bridge>
  #     <interface type='vlan' name='eth0.102'>
  #       <vlan tag='102'>
  #         <interface name='eth0'/>
  #       </vlan>
  #     </interface>
  #   </bridge>
  # </interface>

  my $config  = $self->{config};
  my $tt_path = sprintf "%s/%s", $self->{xml_template_dir_path}, $config->{iface_xml_template_name};
  -f $tt_path
    or croak "*** $tt_path is not found";

  my $xml_data = qq{};
  $self->{tt}->process( $tt_path, $p, \$xml_data );

  return $xml_data;
  
}

1;

