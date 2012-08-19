use warnings;
use strict;
package Murakumo_Node::CLI::Guestfs 0.03;
use IPC::Cmd;
use Carp;
use Data::Dumper;

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
  my ($drive, $mac, $ip, $mask, $gw, $hostname)
    = ($p->{drive}, $p->{mac}, $p->{ip}, $p->{mask}, $p->{gw}, $p->{hostname});

  warn Dumper $p;

  my $command_t = "%s --drive %s --mac %s --ip %s --mask %s --gw %s";
  if ($hostname) {
     $command_t = "%s --drive %s --mac %s --ip %s --mask %s --gw %s --hostname %s";
  }
 
  my $command = sprintf $command_t,
                        $self->{script},
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
