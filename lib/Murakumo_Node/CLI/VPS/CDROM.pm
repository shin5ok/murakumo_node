use warnings;
use strict;

package Murakumo_Node::CLI::VPS::CDROM;
use Path::Class;
use Carp;
use IPC::Open3;
use IPC::Cmd;
use Data::Dumper;

use lib qw( /home/smc/Murakumo_Node/lib );
use Murakumo_Node::CLI::Guestfs;
use Murakumo_Node::CLI::Utils;
use Murakumo_Node::CLI::Libvirt;
use base qw(Murakumo_Node::CLI::Libvirt);

sub change {
  my ($self, $uuid, $cdrom_path) = @_;
  $cdrom_path ||= "/dev/null";
  warn "pre";
  my $r = system "virsh attach-disk --type cdrom $uuid $cdrom_path hdc";
  warn "after $r";
  return $r == 0;
}

1;
