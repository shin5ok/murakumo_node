use warnings;
use strict;

package Murakumo_Node::CLI::Libvirt::IFace;
use Carp;
use XML::TreePP;
use Try::Tiny;
use Path::Class;
use IPC::Cmd;
use Data::Dumper;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;
use Murakumo_Node::CLI::Libvirt;
use base q(Murakumo_Node::CLI::Libvirt);

use Murakumo_Node::CLI::Libvirt::XML;
use Murakumo_Node::CLI::Utils;

our $VERSION = q(0.0.1);
our $config  = Murakumo_Node::CLI::Utils->config;

sub add {
  {
    # いまはスタブ
    return 1;
  } 
  my ($self, $args_ref) = @_;
  my $xml_data = Murakumo_Node::CLI::Libvirt::XML->new->create_iface_for_libvirt( $args_ref );
  warn __PACKAGE__;
  warn $xml_data;

  $self->conn->create_network( $xml_data );
}


sub make_br_and_vlan {

  my ($self, @brs) = @_;

  my $ip_link = qx{/sbin/ip link show};

  for my $br ( @brs ) {
    my ($vlan_id_raw) = $br =~ /(\d+)$/;
    my $vlan_id = int $vlan_id_raw;

    my $nic = $config->{user_nic};
    if (exists $config->{option_nic}
          and exists $config->{option_nic_use_vlan_id_min}
            and exists $config->{option_nic_use_vlan_id_max}) {

      if ($config->{option_nic_use_vlan_id_min} <= $vlan_id
               and $vlan_id <= $config->{option_nic_use_vlan_id_max}) {
           $nic = $config->{option_nic}
      }

    }

    my $vlan_nic = sprintf "%s.%d", $nic, $vlan_id;
    my $vl_f = file("/proc", "net", "vlan", $vlan_nic);

    if (! -e $vl_f->absolute) {
      my $command = "/sbin/vconfig add $nic $vlan_id";
      warn $command;
      my $r = command( $command );
      if (! $r) {
        croak "*** fail command( $command )";
      }
    }

    # upしてるのを確認するために、ip link show コマンドの出力から判断・・・カッコよくない
    if ($ip_link !~ /$vlan_nic\@[^\n]+state\s+UP/) {
      my $command = "/sbin/ifconfig $vlan_nic up";
      my $r = command( $command );
      if (! $r) {
        croak "*** fail command( $command )";
      }
    }

    my $br_f = file("/sys", "class", "net", $br, "flags");
    if (! $br_f->open) {
      my @commands = (
                       "/usr/sbin/brctl addbr $br",
                       "/usr/sbin/brctl addif $br $vlan_nic",
                     );

      for my $command ( @commands ) {
        my $r = command ( $command );
        if (! $r) {
          croak "*** fail command( $command )";
        }
      }
    }

    my $content = $br_f->slurp;
    if ($content !~ /^0x1003$/ms
      or $ip_link !~ /$br\@[^\n]+state\s+UP/) {

        my $command = "/sbin/ifconfig $br up";
        warn $command;
        my $r = command( $command );
        if (! $r) {
          croak "*** fail command( $command )";
        }

    }


    # {
    #   # libvirt の iface に登録
    #   require Murakumo_Node::CLI::Libvirt::IFace;
    #   my $iface_args_ref = {
    #     nic      => $nic,
    #     bridge   => $br,
    #     vlan_nic => $vlan_nic,
    #     vlan_id  => $vlan_id,
    #   };
    #   $self->add( $iface_args_ref );
    # }


  }

}

1;

