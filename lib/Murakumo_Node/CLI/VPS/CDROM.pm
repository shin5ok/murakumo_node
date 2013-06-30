use warnings;
use strict;
use 5.014;

package Murakumo_Node::CLI::VPS::CDROM;
use Path::Class;
use Carp;
use IPC::Open3;
use IPC::Cmd;
use Data::Dumper;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;
use Murakumo_Node::CLI::Libvirt;
use base qw(Murakumo_Node::CLI::Libvirt);

sub change {
  my ($self, $uuid, $cdrom_path) = @_;
  $cdrom_path ||= "/dev/null";
  my $r = system "virsh attach-disk --type cdrom $uuid $cdrom_path hdc";
  return $r == 0;
}

1;
