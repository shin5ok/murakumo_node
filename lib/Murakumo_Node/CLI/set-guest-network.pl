#!/usr/bin/perl
# /etc 以下の設定ファイルの書き換え
use warnings;
use strict;
use Sys::Guestfs;
use Data::Dumper;
use Getopt::Long;
use Carp;

my %opt;
GetOptions( \%opt, "drive=s", "uuid=s", "mac=s", "ip=s", "mask=s", "gw=s", "hostname=s", "nic=s", "project_id=s" );

my $debug = exists $ENV{DEBUG};
warn Dumper \@ARGV if $debug;

for my $key ( qw( drive mac ip mask gw hostname ) ) {
  (exists $opt{$key} and $opt{$key})
    or croak "*** $key parameter error";
}

if ($opt{nic} !~ /^eth\d+/) {
  croak "*** nic name format error";
}

defined $opt{nic}
  or $opt{nic} = "eth0";

my ($drive, $mac, $ip, $mask, $gw, $hostname, $nic, $uuid, $project_id)
  = ($opt{drive}, $opt{mac}, $opt{ip}, $opt{mask}, $opt{gw}, $opt{hostname}, $opt{nic}, $opt{uuid}, $opt{project_id});

my $h = Sys::Guestfs->new;
$h->set_trace(1) if $debug;
$h->set_autosync(1);
$h->add_drive_opts ( $drive, format => 'raw', readonly => 0 );
$h->launch;
my %s = $h->list_filesystems;

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
                 my ($content) = @_;

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
    file    => "/root/.murakumo",
    content => qq[{"uuid":"$uuid","project_id":"$project_id"}],
  },
  {
    file    => "/etc/sysconfig/network-scripts/ifcfg-$nic",
    content => make_cfg_content(),
  },
  {
    file    => "/etc/udev/rules.d/70-persistent-cd.rules",
    code    => sub {
                 my ($content) = @_;
                 my $new_mac = $mac;
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

                 return $content;
               },
    # content => "",
  },
  {
    file    => "/etc/sysconfig/hwconf",
    code    => sub {
                 my ($content) = @_;
                 my $new_mac = $mac;
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

                 return $content;
               },
  },
);

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
            my $new_content = $func->( $content, \%opt );
            if ($new_content) {
              $h->write( $v->{file}, $new_content );
            }
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

sub make_network_content {
  no strict 'refs';
  my $ref      = shift;
  my $hostname = $ref->{hostname};
  if (! exists $ref->{hostname}) {
    my $network_content = $ref->{org_network};
    ($hostname) = $network_content =~ /^ HOSTNAME \s* \= \s* (\S+) /msxi;
  }
  $hostname ||= "CLONED-OS";

  my $_x = << "__EOD__";
NETWORKING=yes
HOSTNAME=$hostname
GATEWAY=$gw
__EOD__
  return $_x;
}

sub make_cfg_content {
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
