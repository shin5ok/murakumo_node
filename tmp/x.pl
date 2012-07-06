#!/usr/bin/perl
use strict;
use warnings;

use Sys::Guestfs;
use Data::Dumper;

my ($drive, $mac, $ip, $mask, $gw) = @ARGV;

my $h = Sys::Guestfs->new ();
$h->set_trace(1);
$h->add_drive_opts ( $drive, format => 'raw');
$h->launch ();
my %s = $h->list_filesystems;

warn Dumper \%s;

my $ok = 0;
my $cfg_content = make_cfg_content();
my $file = "/etc/sysconfig/network-scripts/ifcfg-eth0";
for my $dev ( keys %s ) {
  $s{$dev} eq 'swap' and next;
  $h->mount( $dev, '/' );
  if ($h->exists($file)) {
    $ok = $h->write( $file, $cfg_content );    
  }
}

$h->sync;

exit;

# $h->mount_options ('', $partitions[0], '/');

# print join "\n", $h->find('/etc');

sub make_cfg_content {
my $_x = << "__EOD__";
DEVICE=eth0
IPADDR=$ip
NETMASK=$mask
HWADDR=$mac
ONBOOT=yes
__EOD__
}
