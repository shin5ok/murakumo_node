use warnings;
use strict;

package Murakumo_Node::CLI::Node;
use lib qw( /home/smc/Murakumo_Node/lib );
use Murakumo_Node::CLI::Libvirt;
use base q(Murakumo_Node::CLI::Libvirt);

use Carp;
use Data::Dumper;
use Try::Tiny;

our $VERSION = q(0.0.1);

sub list_vps_ids {
  my $self = shift;
  my @ids;

  # vpsのリストを更新
  $self->_reload_list_domains;
  for my $domain_obj ( @{$self->{_domains}} ) {
    push @ids, $domain_obj->get_id;
  }
  return @ids;
}

sub list_vps_uuids {
  my $self = shift;
  my @uuids;
  # vpsのリストを更新
  $self->_reload_list_domains;
  for my $domain_obj ( @{$self->{_domains}} ) {
    push @uuids, $domain_obj->get_uuid_string;
  }
  return @uuids;
}

sub _reload_list_domains {

  my $self = shift;

  my $conn = $self->conn;
  my @domains = $conn->list_domains;
  $self->{_domains} = \@domains;

  return $self;
}


1;
