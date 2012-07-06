use warnings;
use strict;

package Murakumo_Node::CLI::VPS::Migration 0.01;
use Carp;
use JSON;
use Data::Dumper;
use IPC::Cmd;

use lib qw( /home/smc/Murakumo_Node/lib );
use Murakumo_Node::CLI::Guestfs;
use Murakumo_Node::CLI::Utils;
use Murakumo_Node::CLI::Libvirt;
use base qw(Murakumo_Node::CLI::Libvirt);

our $utils   = Murakumo_Node::CLI::Utils->new;
our $config  = $utils->config;
our $vm_root = $config->{vm_root};

sub run {
  my ($self, $argv) = @_;
  dumper($argv);

  my $dst_node = $argv->{dst_node};
  my $uuid     = $argv->{uuid};
  my $info     = $argv->{info};

  $dst_node
    or croak "*** dst node is not found";
  $uuid
    or croak "*** vps uuid is not found";

  my @interfaces = map { sprintf "br%04d", $_->{vlan_id} } @{$info->{interfaces}};
  my @disks      = map { $_->{image_path}                } @{$info->{disks}};

  my $br_and_storage = +{ br => \@interfaces, storage => \@disks, };

  {
    my $api_uri  = sprintf "http://%s:%d/", $dst_node, $config->{api_port};
    warn "api_uri: $api_uri";

    require Murakumo_Node::CLI::Remote_JSON_API;
    my $api_response = Murakumo_Node::CLI::Remote_JSON_API
                                  ->new($api_uri)
                                  ->json_post('/node/setup_node/', $br_and_storage );

    my $api_result = decode_json $api_response->content;
    if (! $api_result->{result}) {
      warn Dumper $api_result;
      croak "*** setup_node is failure";
    }
  }

  my $uri = sprintf "qemu+ssh://%s/system", $dst_node;

  return scalar IPC::Cmd::run( command => "virsh migrate $uuid $uri", timeout => 600, verbose => 1, );

#   # $dom->migrate_to_uri(desturi, flags, dname, bandwidth)
#   my $domain = $self->conn->get_domain_by_uuid( $uuid );
#   $domain->migrate_to_uri( $uri );
}
