use warnings;
use strict;

package Murakumo_Node::CLI::VPS 0.05;
use XML::TreePP;
use Carp;
use Try::Tiny;
use Path::Class;
use IPC::Cmd;
use Data::Dumper;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Libvirt;
use Murakumo_Node::CLI::Utils;
use base qw(Murakumo_Node::CLI::Libvirt);

my $config = Murakumo_Node::CLI::Utils->new->config;

sub new {
  my ($class, $argv) = @_;

  my $self = $class->SUPER::new;

  # ドメインオブジェクトが作れなかったら、ここで例外発生
  $argv and $self->domain_obj( $argv );

  return $self;

}

sub _get_domain_obj {
  my ($self, $argv) = @_;

  my $conn = $self->conn;
  my $domain_obj;

  {
    no strict 'refs';
    # uuidが最優先
    if ( exists $argv->{uuid} and $argv->{uuid} ) {
      $domain_obj = $conn->get_domain_by_uuid($argv->{uuid});
    }
    elsif ( exists $argv->{id} and $argv->{id} ) {
      $domain_obj = $conn->get_domain_by_id($argv->{id});
    }

  }

  $self->{_domain_obj} = $domain_obj;

  return 1;
}

# domain objectへのアクセサ
sub domain_obj {
  my ($self, $argv) = @_;

  if ($argv) {
    $self->_get_domain_obj( $argv );
    return 1;

  } else {
    if ( ! exists $self->{_domain_obj}) {
      confess "*** error domain_obj empty";
    }
    return $self->{_domain_obj};

  }
 
}

sub boot2 {
  my ($self, $args_ref) = @_;

  my $result = 0;

  no strict 'refs';
  my $vps_params    = $args_ref->{vps_params};
  my $clean_traffic = $args_ref->{clean_traffic} || 0;
  my $cdrom_boot    = $args_ref->{cdrom_boot}    || 0;
  my $disk_cache    = $args_ref->{disk_cache};
  {
    my @require_keys = qw(
      disks     
      interfaces
      cpu_number
      memory
      clock
      uuid
      vnc_password
    );

    # パラメータの存在のチェック
    for my $key ( @require_keys ) {
      exists $vps_params->{$key}
        or croak "param $key is not found";
    }
  }

  require Murakumo_Node::CLI::Libvirt::XML;
  my $x = Murakumo_Node::CLI::Libvirt::XML->new;

  my $callback_uri = sprintf "%s/vps/boot_tmp_cleanup/", $config->{api_uri};

  require Murakumo_Node::CLI::Job::Callback;
  my $callback = Murakumo_Node::CLI::Job::Callback->new({ uri => $callback_uri, retry_by_mail => 1, });

  local $@;
  eval {

    # ネットワーク
    my @interfaces;
    my @disks;
    my @ready_brs;
    my @ready_storage_pools;

    warn "--- CLI::VPS ---";
    warn Dumper $args_ref;
    warn "----------------";

    for my $interface ( @{$vps_params->{interfaces}} ) {

      my $bridge = exists $interface->{bridge}
                 ? $interface->{bridge}
                 : sprintf "br%04d", $interface->{vlan_id};

      my $r = {
        bridge        => $bridge,
        mac           => $interface->{mac},
        driver        => $interface->{driver},
        ip            => $interface->{ip}->{ip} || 0,
        vlan_id       => $interface->{vlan_id},
        clean_traffic => $clean_traffic,
      };

      my $xml_data = $x->create_interface_xml( $r );
      
      push @interfaces, $xml_data;
      push @ready_brs,  $bridge;

    }

    # ディスク
    my @virtio_blockname_char    = ('a' .. 'z');           # 24
    my @nonvirtio_blockname_char = ('a', 'b', 'd' .. 'z'); # 23
    my $virtio_disk_number       = 0;
    my $nonvirtio_disk_number    = 0;

    for my $disk ( @{$vps_params->{disks}} ) {

      my $r = +{};

      my $disk_number    = \$virtio_disk_number;
      my $blockname_char = \@virtio_blockname_char;
      my $disk_prename   = "vd";
      my $driver         = 'virtio';

      my $controller;
      if ( exists $disk->{driver} and $disk->{driver} ne 'virtio' ) {
        $disk_prename   = "hd";
        $blockname_char = \@nonvirtio_blockname_char;
        $disk_number    = \$nonvirtio_disk_number;
        $driver         = 'ide';

        # 0, 0 は cdromで使っています
        my ($bus, $unit) = $$disk_number == 0
                         ? (0, 1)
                         : $$disk_number == 1
                         ? (1, 0)
                         : $$disk_number == 2
                         ? (1, 1)
                         : (undef, undef)
                         ;

        if (! defined $bus and ! defined $unit) {
          croak "*** disk device ide no more available";
        }

        $controller = { bus => $bus, unit => $unit };
      }

      $r = {
        image_path => $disk->{image_path},
        devname    => (sprintf "%s%s", $disk_prename, $blockname_char->[$$disk_number]),
        driver     => $driver,
        disk_cache => $disk_cache,
      };
      $controller and $r->{controller} = $controller;
      
      my $xml_data = $x->create_disk_xml( $r );
      
      push @disks, $xml_data;
      push @ready_storage_pools, $disk->{image_path};

      $$disk_number++;
    }


    my $vps_xml_data;
    {
    
      my $uuid = $vps_params->{uuid};
    
      my $r = {
        name       => $vps_params->{name},
        uuid       => $vps_params->{uuid},
        memory     => $vps_params->{memory},
        cpu        => $vps_params->{cpu_number},
        clock      => $vps_params->{clock},
        cdrom_boot => $cdrom_boot,
      };

      exists $vps_params->{cdrom_path}
        and $r->{cdrom_path}   = $vps_params->{cdrom_path};

      exists $vps_params->{vnc_password}
        and $r->{vnc_password} = $vps_params->{vnc_password};

      
      $vps_xml_data = $x->create_vps_xml( $r, \@disks, \@interfaces, );

    }

    $self->make_bridge_and_storage_pool({
                                           br      => \@ready_brs,
                                           storage => \@ready_storage_pools,
                                        });

    warn "----- XML for VPS ---------------------------------------------------------------";
    warn $vps_xml_data;
    warn "---------------------------------------------------------------------------------";
    {
      open my $fh, ">", "/tmp/$vps_params->{uuid}.xml";
      flock $fh, 2;
      print {$fh} $vps_xml_data;
      close $fh;
    }

    $self->conn->create_domain( $vps_xml_data ) and $result = 1;
  };

  $@ and warn $@;

  require Sys::Hostname;
  my $my_nodename = Sys::Hostname::hostname();
  my %callback_params = (
                            uuid    => $vps_params->{uuid},
                            result  => $result,
                            node    => $my_nodename,
                            message => qq{},
                          );

  $@ and $callback_params{message} = ref $@ eq q{Sys::Virt::Error}
                                   ? $@->stringify
                                   : $@;
  $callback->set_params( \%callback_params );

  return $result;

}

sub test { warn __PACKAGE__ . "::test" }

sub make_bridge_and_storage_pool {
  my ($self, $hash_ref) = @_;
  warn "make_bridge_and_storage_pool";
  warn Dumper $hash_ref;

  my $fail_count = 0;

  if (exists $hash_ref->{br}) {
    require Murakumo_Node::CLI::Libvirt::IFace;
    my $libvirt_iface = Murakumo_Node::CLI::Libvirt::IFace->new;
    for my $br ( @{$hash_ref->{br}} ) {
      $libvirt_iface->make_br_and_vlan( $br )
        or $fail_count++;
    }
  }

  if (exists $hash_ref->{storage}) {
    require Murakumo_Node::CLI::Libvirt::Storage;
    my $libvirt_storage = Murakumo_Node::CLI::Libvirt::Storage->new;
    for my $storage_path ( @{$hash_ref->{storage}} ) {
      if (! $libvirt_storage->add_by_path( $storage_path )) {
        logging "add_by_path $storage_path failure";
        $fail_count++;
        next;
      }
    }
  }

  return $fail_count == 0;

}

sub parse_xml {
  my $self = shift;
  my $file = shift;

  my $xml_tpp = XML::TreePP->new( force_array => '*' );
  my $xml = $xml_tpp->parsefile ( $file );
  warn Dumper $xml;
  return $xml;

}

sub shutdown {
  my ($self) = @_;
  $self->operation( "shutdown" );
}

sub terminate {
  my ($self) = @_;
  $self->operation( "destroy" );
}

sub get_xml_ref {
  my ($self)   = @_;
  my $domain   = $self->domain_obj;
  my $xml_data = $domain->get_xml_description;
  return XML::TreePP->new->parse( $xml_data );
}

sub is_active {
  my ($self) = @_;
  my $domain = $self->domain_obj;
  return $domain->is_active;
}

sub operation {
  my ($self, $mode, @args ) = @_;

  my $fail = 0;
  my $r;
  local $_;
  try {
    my $domain = $self->domain_obj;
    $r = $domain->$mode( @args );

  } catch {
    warn "exeption: $_" if $_;
    $fail = 1;

  };

  return $fail == 0;
}

sub clone {
  my ($self, @args) = @_;
  require Murakumo_Node::CLI::VPS::Disk;
  return &Murakumo_Node::CLI::VPS::Disk::clone;
}

sub migration {
  my ($self, $argv) = @_;

  require Murakumo_Node::CLI::VPS::Migration;
  return &Murakumo_Node::CLI::VPS::Migration::run;

}

1;
