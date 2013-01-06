#!/usr/bin/perl
# /etc 以下の設定ファイルの書き換え
use warnings;
use strict;

use Sys::Guestfs;
use Data::Dumper;
use Getopt::Long;
use Carp;

our $min_nic = 0; # eth0
our $max_nic = 5; # eth5

# {
#   "drive" : "/vm/55555555555555555555/vps001.img",
#   "network" : [
#                 {
#                   "nic" : "eth0",
#                   "ip"  : "210.172.63.2",
#                   "mask": "255.255.255.0",
#                   "mac" : "xx:xx:xx:xx:xx:xx",
#                 },
#                 {
#                   "nic" : "eth1",
#                   "ip"  : "192.168.232.10",
#                   "mask": "255.255.252.0",
#                   "mac" : "xx:xx:xx:xx:xx:yy",
#                 },
#               ],
#   "hostname" : "vps001.example.com",
#   "gw"  : "210.172.63.1",
# }
#

my $debug = exists $ENV{DEBUG};
warn Dumper \@ARGV if $debug;

my $drive;
my $h = Sys::Guestfs->new;
$h->set_trace(1) if $debug;
$h->set_autosync(1);
$h->add_drive_opts ( $drive, format => 'raw', readonly => 0 );
$h->launch;
my %s = $h->list_filesystems;

my $params = get_params();

# code の仕様
# 引数
#   1. 元の設定ファイルの内容
#   2. %opt(GetOptionsで設定されたハッシュ)のreference
# 戻り値
#   新しい設定ファイルの内容
my @write_files_content_array = (
  {
    file    => "/etc/sysconfig/network",
    code    => sub {
                 my ($content, $params) = @_;

                 my $hostname = $params->{hostname};
                 my $gw       = $params->{gw};

                 my $old_hostname = "";
                 if (($old_hostname) = $content =~ /^HOSTNAME\s*\=\s*(\S+)/msi) {
                   $hostname ||= sprintf "%s-cloned", $old_hostname;
                   $content =~ s/$old_hostname/$hostname/;
                 } else {
                   $content .= "HOSTNAME=cloned\n";
                 }

                 if ($content =~ /^(GATEWAY\s*\=\s*)(\S+)/sim) {
                   if ($2 ne $gw) {
                     $content =~ s/$1$2/GATEWAY=$gw/;
                   }

                 } else {
                   $content .= "GATEWAY=$gw\n";

                 }

                 return $content;
               },
  },    
  {
    file    => "/etc/udev/rules.d/70-persistent-cd.rules",
    code    => sub {
                 my ($content, $params) = @_;

                 for my $x ( @{$params->{network}} ) {
                   my $new_mac = $x->{mac};
                   my $nic     = $x->{nic};

                   $new_mac or return;

                   # SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="78:2b:cb:2a:18:31", ATTR{type}=="1", KERNEL=="eth*", NAME="$nic"

                   my $old_mac;
                   __FILE_LINE__:
                   for my $line ( split /\n/, $content ) {
                     $line =~ /^\s* #/x 
                       or next __FILE_LINE__;

                     $line =~ / NAME \s* \= \s* \"? $nic \"? /x
                       or next __FILE_LINE__;
                     ($old_mac) =
                       $line =~ /
                                   \s*ATTR\{address\}
                                   \s*\=\=\s*
                                   \"([^\"]+)\"   
                                 /x;

                        last __FILE_LINE__;

                   }

                   warn "persistent =~ s/$old_mac/$new_mac/" if $debug;
                   $old_mac and
                     $content =~ s/$old_mac/$new_mac/;
                 }

                 return $content;
               },
    # content => "",
  },
  {
    file    => "/etc/sysconfig/hwconf",
    code    => sub {

                 my ($content, $params) = @_;
                 
                 for my $x ( @{$params->{network}} ) {
                   my $new_mac = $x->{mac};
                   my $nic     = $x->{nic};

                   $new_mac or return;

                   my ($nic_part)
                     = $content =~ /
                       ^ \- $
                       (
                         [^\-]*
                         device : \s* $nic \s* $
                         [^\-]*
                       )
                       ^ \- $
                     /xsm;

                     warn "nic_part: ", $nic_part if $debug;


                   $nic_part or return $content;

                   my ($old_mac) = $nic_part =~ /
                     ^ network \. hwaddr : \s* (\S+)
                     /xsm;

                   warn "hwconf =~ s/$old_mac/$new_mac/" if $debug;
                   $old_mac and
                     $content =~ s/$old_mac/$new_mac/;
                   }

                 return $content;
               },
  },
);

for my $number ( $min_nic .. $max_nic ) {
  push @write_files_content_array,
    +{
      file    => "/etc/sysconfig/network-scripts/ifcfg-eth$number",
      content => make_cfg_content("eth$number", $params),
    };
}

my $failure = 0;
FILESYSTEMS: for my $dev ( keys %s ) {

  $s{$dev} =~ m|^ext[34]$| or next;
  $h->mount( $dev, '/' );
  if ($h->exists( '/etc' )) {

    __WRITE_FILES__:
    for my $v ( @write_files_content_array ) {
      if ( exists $v->{content} ) {
        $h->write( $v->{file}, $v->{content} );
      }
      elsif ( exists $v->{code} ) {
        if ( $h->exists( $v->{file} )) {
          my $content;
          local $@;
          eval {
            $content = $h->read_file( $v->{file} );
            my $func = $v->{code};
            my $new_content = $func->( $content, $params );
            $h->write( $v->{file}, $new_content );
          };
          if ($@) {
            $failure = 1;
            next __WRITE_FILES__;
          }
        }
      }
    }

    last FILESYSTEMS;

  } else {
    $h->umount( $dev );
  }
}

if ($failure) {
  $debug and warn "*** cfg write error";
  exit 1;

} else {
  $debug and warn "cfg write ok";
  exit 0;

}

sub make_cfg_content {
  my $nic    = shift;
  my $params = shift;

  my ($ip,$mask,$mac);
  for my $x (@{$params->{network}}) {
    exists $x->{$nic} or next;
    $ip   = $x->{$nic}->{ip};
    $mask = $x->{$nic}->{mask};
    $mac  = $x->{$nic}->{mac};
  }

  if (! $ip or ! $mask or ! $mac) {
    return;
  }

  my $_x = << "__EOD__";
DEVICE=$nic
IPADDR=$ip
NETMASK=$mask
HWADDR=$mac
ONBOOT=yes
BOOTPROTO=static
__EOD__

  return $_x;
}

sub get_params {

}

