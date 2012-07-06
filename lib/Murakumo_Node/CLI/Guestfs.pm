use warnings;
use strict;
package Murakumo_Node::CLI::Guestfs;
use IPC::Cmd;
use Data::Dumper;

our $script = "/home/smc/Murakumo_Node/lib/Murakumo_Node/CLI/set-guest-network.pl";

sub new {
  my $obj = bless {};
  return $obj;
}

sub set_network {

  my ($self, $p) = @_;
  no strict 'refs';
  my ($drive, $mac, $ip, $mask, $gw, $hostname)
    = ($p->{drive}, $p->{mac}, $p->{ip}, $p->{mask}, $p->{gw}, $p->{hostname});

  warn Dumper $p;

  my $command_t = "%s --drive %s --mac %s --ip %s --mask %s --gw %s";
  if ($hostname) {
     $command_t = "%s --drive %s --mac %s --ip %s --mask %s --gw %s --hostname %s";
  }
 
  my $command = sprintf $command_t,
                        $script,
                        $drive,
                        $mac,
                        $ip,
                        $mask,
                        $gw,
                        $hostname;
  warn "[ $command ]";

  # $IPC::Cmd::VERBOSE = 1;

  my $r = IPC::Cmd::run(
            command => $command,
            verbose => 1,
            timeout => 50,
          );
  
  if ($r) {
    warn "ok";
    return 1;

  } else {
    warn "NG";
    return 0;

  }


}

1;
