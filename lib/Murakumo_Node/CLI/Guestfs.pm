use warnings;
use strict;

package Murakumo_Node::CLI::Guestfs 0.03;
use IPC::Cmd;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;

our $script = "/usr/local/bin/set-guest-network.pl";

sub new {
  my $class       = shift;
  my $script_path = shift;
  $script_path ||= $script;

  my $obj = bless {};
  $obj->{script} = $script_path;

  -x $obj->{script}
    or croak "*** $obj->{script} is not execute...";

  return $obj;

}

sub set_network {

  my ($self, $p) = @_;
  no strict 'refs';
  my ($drive, $mac, $ip, $mask, $gw, $hostname, $nic, $uuid, $project_id)
    = ($p->{drive}, $p->{mac}, $p->{ip}, $p->{mask}, $p->{gw}, $p->{hostname}, $p->{nic}, $p->{uuid}, $p->{project_id});

  my $command_t = "%s --drive %s --uuid %s --mac %s --ip %s --mask %s --gw %s";

  $hostname and
    $command_t .= " --hostname $hostname";

  $nic and
    $command_t .= " --nic $nic";

  $project_id and
    $command_t .= " --project_id $project_id";

  my $command = sprintf $command_t,
                        $self->{script},
                        $drive,
                        $uuid,
                        $mac,
                        $ip,
                        $mask,
                        $gw,
                        $hostname;

  logging $command;

  my $r = IPC::Cmd::run(
            command => $command,
            verbose => 1,
            timeout => 50,
          );

  if ($r) {
    logging "set_network ok";
    return 1;

  } else {
    logging "set_network NG";
    return 0;

  }


}

1;
