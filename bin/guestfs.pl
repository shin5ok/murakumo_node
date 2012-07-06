#!/usr/bin/perl
use strict;
use warnings;
use Sys::Guestfs;

my ($drive, $mac, $ip, $mask, $gw) = @ARGV;

my $eth0_cfg = make_cfg( $mac, $ip, $mask, $gw );

my $s = Sys::Guestfs->new;
$s->add_drive( $drive );
$s->launch;
$s->mount( '/dev/VolGroup/lv_root', '/' );
$s->write_file( '/etc/sysconfig/network-scripts/ifcfg-eth0', $eth0_cfg, 0 );
$s->sync;

sub make_cfg {
  my ( $mac, $ip, $mask, $gw ) = @_;
  my $data = << "__END_OF_CFG__";
DEVICE=eth0
HWADDR=$mac
IPADDR=$ip
NETMASK=$mask
ONBOOT=yes
__END_OF_CFG__

  return $data;
}

__END__
my $guestfs = Sys::Guestfs->new;
$guestfs->add_drive($image);
$guestfs->launch;
$guestfs->mount( '/dev/mapper/VolGroup00-LogVol00', '/' );
$guestfs->write_file( '/etc/sysconfig/network-scripts/ifcfg-eth0', $content, 0 );
$guestfs->sync;

