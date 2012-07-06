#!/home/smc/bin/perl
# chkconfig: - 99 10
# description: smc_vps2 for node submit my condition

use strict;
use warnings;
use Sys::Virt;
use LWP::UserAgent;
use HTTP::Request::Common q(POST);
use Data::Dumper;
use URI;
use JSON;
use POSIX;
use Sys::Hostname;
use Sys::Syslog qw(:DEFAULT setlogsock);
use Path::Class;
use App::Daemon qw( daemonize );
use XML::TreePP;
use Carp;
use File::Basename;

use lib qw( /home/smc/Murakumo_Node/lib );
use Murakumo_Node::CLI::Utils;
use Murakumo_Node::CLI::Remote_JSON_API;

$App::Daemon::kill_sig = SIGINT;
$App::Daemon::pidfile  = "/var/run/" . basename __FILE__ . ".pid";
$App::Daemon::logfile  = "/var/log/" . basename __FILE__ . ".log";
$App::Daemon::as_user  = "root";

my $config    = Murakumo_Node::CLI::Utils->config;
my $web_agent = Murakumo_Node::CLI::Remote_JSON_API->new(qq{http://$config->{callback_host}:3000});

my $node  = hostname();
daemonize() if ! exists $ENV{DEBUG};

# libvirt への接続
our $vmm;
while (1) {
  local $@;
  eval {
    post_state();
  };
  $@ and syslog_write($@);
  sleep 3;
}

sub syslog_write {
  # setlogsock 'unix';
  my $log = shift;
  openlog __FILE__, 'local0';
  warn $log, "\n";
  syslog 'info', $log;
  closelog;
}

sub post_state {
  chomp ( my $update_key = qx{uuidgen} );
  my $parameter = {};
  syslog_write("pre gather from libvirt");
  my $vps_ref   = _gathering_vps();
  syslog_write("after gather from libvirt");

  my $cpu_vps_used = 0;
  for my $v ( @$vps_ref ) {
    $cpu_vps_used += $v->{cpu};
  }

  my $node_ref = _gathering_node();

  $node_ref->{name} = $node;
  $node_ref->{cpu_vps_used} = $cpu_vps_used;
  $node_ref->{vps_number}   = scalar @$vps_ref;
  $node_ref->{cpu_available} = $node_ref->{cpu_total} - $cpu_vps_used;
  
  {
    no strict 'refs';
    $parameter->{vpses} = $vps_ref;
    $parameter->{node}  = $node_ref;
    $parameter->{update_key} = $update_key;
  }
  warn Dumper $parameter if $ENV{DEBUG};

  my $response = $web_agent->json_post('/node/register', $parameter);
  if ($response->is_success) {
    syslog_write( $response->content );
  } else {
    syslog_write( sprintf "%s :%s", $response->content, $response->code );
  }
}

sub get_libvirt_conn {
# ここ libvirtd を再起動したら、メソッドを呼んだ段階で停止してしまう
# 避けられそうにないので
# - 毎回libvirtdに接続するか
#  return Sys::Virt->new;
# - 子プロセスを切り離してloopをまわし、子プロセスが停止したら、
#   定期的に再試行を繰り返す親プロセスを作る
#   Parallel::Prefork とかを使って
# とりあえず、前者で。
  {
    my $vmm = Sys::Virt->new;
    return $vmm;
  }

  our $vmm;
  local $@;
  eval {
    # $vmm が false なら
    warn;
    $vmm ||= Sys::Virt->new;
    warn;

    # libvirt のメソッドが正しく呼べなければ、
    warn;
    $vmm->can("get_version") or croak "error";
    warn;
  };
  warn $@;
  if ($@) {
    $vmm = Sys::Virt->new;
    syslog_write("conn to libvirt $@");
  }

  return $vmm;
}

sub _gathering_vps {
  local $Data::Dumper::Terse = 1;

  my $vmm = get_libvirt_conn();
  my @domains;

  my @parameters;
  eval {
    for my $dom ($vmm->list_domains) {
      my $uuid = $dom->get_uuid_string;
      my $info = $dom->get_info;
      my $name = $dom->get_name;
      my $xml  = XML::TreePP->new( force_array => 'disk' )->parse( $dom->get_xml_description );

      my $vnc_port = 0;
      my @disks;
      {
        no strict 'refs';
        if (exists $xml->{domain}->{devices}->{graphics}) {
          if ($xml->{domain}->{devices}->{graphics}->{'-type'} eq q{vnc}) {
            $vnc_port = $xml->{domain}->{devices}->{graphics}->{'-port'};
          }
        }
        
        my @disk_infos = sort { $a->{address}->{'-bus'} cmp $b->{address}->{'-bus'} }
                         grep { exists $_->{source}->{'-file'} }
                              @{$xml->{domain}->{devices}->{disk}};

        push @disks, $disk_infos[0]->{source}->{'-file'};

      }

      my $tmp  = {
        uuid     => $uuid,
        name     => $name,
        state    => $info->{state},
        cpu      => $info->{nrVirtCpu},
        memory   => $info->{memory},
        vnc_port => $vnc_port,
        disks    => join ',', @disks,
      };

      push @parameters, $tmp;
    }
  };
  \@parameters;
}

sub _gathering_node {
  my @cpus;
  {
    my $cpuinfo = file( '/proc/cpuinfo' );
    my @cpuinfos = split /\n/, $cpuinfo->slurp;
    @cpus = grep { /^processor \s* : \s* \d+/xo } @cpuinfos;
    # $cpuinfo->close;
  }

  my $mem_free  = 0;
  my $mem_total = 0;
  {
    my $mem = file( '/proc/meminfo' );
    my $fo  = $mem->openr;
    while (my $line = $fo->getline) {
      # MemFree:         5310108 kB
      # Buffers:          270368 kB
      # Cached:          1041248 kB
      if ($line =~ / ^ \s* (?: MemFree | Buffers | Cached ) \s* : \s+ (\d+) /x) {
        $mem_free += $1;
      }
      if ($line =~ / MemTotal \s* : \s+ (\d+) /x) {
        $mem_total = $1; 
      }
    }
  }

  my $load = file( '/proc/loadavg' );
  my $lo = $load->openr;

  my ($loadavg) = $lo->getline =~ /^\s*(\S+)/;

  return {
           cpu_total => scalar @cpus,
           mem_total => $mem_total,
           mem_free  => $mem_free,
           loadavg   => $loadavg,
         };

}

__END__
----------------------------------
[get_uuid_string]
'e7fb1e93-91bc-197e-5cc7-515664ecf6bf'

[get_name]
'relay-vm101'

[get_info]
{
  'cpuTime' => '110090000000',
  'memory' => 2097152,
  'maxMem' => 2097152,
  'nrVirtCpu' => 2,
  'state' => 1
}

----------------------------------
[get_uuid_string]
'a10e2c23-fcaa-ed3c-bedb-e3af0f471878'

[get_name]
'relay-vm000'

[get_info]
{
  'cpuTime' => '107940000000',
  'memory' => 2097152,
  'maxMem' => 2097152,
  'nrVirtCpu' => 2,
  'state' => 1
}
