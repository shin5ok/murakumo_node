#!/usr/bin/perl
use strict;
use warnings;

use Sys::Guestfs;
use Data::Dumper;
use Getopt::Long;
use Carp;

my %opt;
GetOptions( \%opt, "drive=s", "mac=s", "ip=s", "mask=s", "gw=s", "hostname=s");

my $debug = exists $ENV{DEBUG};
warn Dumper \@ARGV if $debug;

my ($drive, $mac, $ip, $mask, $gw, $hostname)
  = ($opt{drive}, $opt{mac}, $opt{ip}, $opt{mask}, $opt{gw}, $opt{hostname});

my $h = Sys::Guestfs->new;
$h->set_trace(1) if $debug;
$h->set_autosync(1);
$h->add_drive_opts ( $drive, format => 'raw', readonly => 0 );
$h->launch;
my %s = $h->list_filesystems;

my $ok = 0;
my $cfg_content = make_cfg_content();

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
                 my ($content, $opt_ref) = @_;
                 my $hostname = $opt_ref->{hostname};

                 my $old_hostname = "";
                 if (($old_hostname) = $content =~ /^HOSTNAME\s*\=\s*(\S+)/msi) {
                   $hostname ||= sprintf "%s-cloned", $old_hostname;
                   $content =~ s/$old_hostname/$hostname/;
                 } else {
                   $content .= "HOSTNAME=cloned\n";
                 }

                 if ($content =~ /^(GATEWAY\s*\=\s*\S+)/i) {
                   $content =~ s/$1/GATEWAY=$gw/;
                 } else {
                   $content .= "GATEWAY=$gw\n";
                 }

                 return $content;
               },
  },    
  {
    file    => "/etc/sysconfig/network-scripts/ifcfg-eth0",
    content => make_cfg_content(),
  },    
  {
    file    => "/etc/udev/rules.d/70-persistent-cd.rules",
    code    => sub {
                 my ($content, $opt_ref) = @_;
                 my $new_mac = $opt_ref->{mac};
                 $new_mac or return;

                 # SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="78:2b:cb:2a:18:31", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"

                 my $old_mac;
                 __LINE__:
                 for my $line ( split /\n/, $content ) {
                   $line =~ /^\s* #/x 
                     or next __LINE__;

                   $line =~ / NAME \s* \= \s* \"? eth0 \"? /x
                     or next __LINE__;
                   ($old_mac) =
                     $line =~ /
                                 \s*ATTR\{address\}
                                 \s*\=\=\s*
                                 \"([^\"]+)\"   
                               /x;

                      last __LINE__;

                 }

                 warn "persistent =~ s/$old_mac/$new_mac/";
                 $old_mac and
                   $content =~ s/$old_mac/$new_mac/;

                 return $content;
               },
    # content => "",
  },
  {
    file    => "/etc/sysconfig/hwconf",
    code    => sub {
                 system "touch /tmp/kawano";
                 my ($content, $opt_ref) = @_;
                 my $new_mac = $opt_ref->{mac};
                 $new_mac or return;

                 my ($eth0_part)
                   = $content =~ /
                     ^ \- $
                     (
                       [^\-]*
                       device : \s* eth0 \s* $
                       [^\-]*
                     )
                     ^ \- $
                   /xsm;

                   warn "eth0_part: ", $eth0_part;


                 $eth0_part or return $content;

                 my ($old_mac) = $eth0_part =~ /
                   ^ network \. hwaddr : \s* (\S+)
                   /xsm;

                 warn "hwconf =~ s/$old_mac/$new_mac/";
                 $old_mac and
                   $content =~ s/$old_mac/$new_mac/;

                 return $content;
               },
    # content => "",
  },
);

FILESYSTEMS: for my $dev ( keys %s ) {

  $s{$dev} eq 'swap' and next;
  $h->mount( $dev, '/' );
  if ($h->exists( '/etc' )) {

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
          };
          $@ and next;
          my $func    = $v->{code};
          my $new_content = $func->( $content, \%opt );
          $h->write( $v->{file}, $new_content );
        }
      }
    }

    if ($h->sync) {
      $ok = 1;
    }

    last FILESYSTEMS;

  }
}

if (! $ok) {
  $debug and warn "*** cfg write error";
    exit 1;

} else {
  $debug and warn "cfg write ok";
    exit 0;

}

sub make_network_content {
  no strict 'refs';
  my $ref      = shift;
  my $hostname = $ref->{hostname};
  if (! exists $ref->{hostname}) {
    my $network_content = $ref->{org_network};
    ($hostname) = $network_content =~ /^ HOSTNAME \s* \= \s* (\S+) /msxi;
  }
  $hostname ||= "CLONED_OS";

  my $_x = << "__EOD__";
NETWORKING=yes
HOSTNAME=$hostname
GATEWAY=$gw
__EOD__
  return $_x;
}

sub make_cfg_content {
  my $_x = << "__EOD__";
DEVICE=eth0
IPADDR=$ip
NETMASK=$mask
HWADDR=$mac
ONBOOT=yes
BOOTPROTO=static
__EOD__
warn "+++++++++++++++++++";
warn $_x;
warn "+++++++++++++++++++";
  return $_x;

}
