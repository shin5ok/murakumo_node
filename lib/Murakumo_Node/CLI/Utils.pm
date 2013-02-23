use strict;
use warnings;
package Murakumo_Node::CLI::Utils 0.05;
use URI;
use JSON;
use Data::Dumper;
use Carp;
use HTTP::Request::Common qw/ POST GET /;
use LWP::UserAgent;
use Config::General;
use Sys::Syslog qw(:DEFAULT setlogsock);
use IPC::Open2;
use Log::Log4perl;

use FindBin;
our $config_path     = qq{/home/smc/murakumo_node/murakumo_node.conf};
our $log_config_path = qq{/home/smc/murakumo_node/log4perl.conf};

sub import {
  my $caller = caller;
  no strict 'refs';
  *{"${caller}::critical"}   = \&critical;
  *{"${caller}::command"}    = \&command;
  *{"${caller}::remove_set"} = \&remove_set;
  *{"${caller}::is_debug"}   = \&is_debug;
  *{"${caller}::dumper"}     = \&dumper;
  *{"${caller}::logger"}     = \&logger;
}

sub new {
  bless {}
}

sub dumper {
  my $ref = shift;

  my ($package, $filename, $line) = caller;
  my $file_path = sprintf "/tmp/%s,%s",
                           $package,
                           $line;
  warn "file_path: ", $file_path if is_debug();
  open my $fh, ">", $file_path;
  flock $fh, 2;
  print {$fh}     Dumper($ref);
  print {*STDERR} Dumper($ref);
  close $fh;
}


sub critical {
  my ($string) = @_;

  # メソッド呼び出しの場合、第一引数は無視
  ref $string
    and $string = $_[1];

  # 致命的なエラー
  # エスカレ対象
  # 将来的には、HG::Escalation を呼ぶ
  setlogsock "unix";
  openlog $$, "ndelay", "local0";
  my $caller = caller;
  syslog "info", "[critical]: called by %s, %s", $caller, $string;
  closelog;
}

sub config {
  my ($self, $config) = @_; 
  $config ||= $config_path;

  my %param;
  local $@;
  eval {
    my $c  = Config::General->new( $config );
    %param = $c->getall;
  };

  if ($@) {
    warn $@;
    return {};
  }

  return \%param;

}

sub is_debug {
  my @callers = caller;
  return exists $ENV{DEBUG} and $ENV{DEBUG};
}

sub create_random_mac {
  my ($self) = @_;
  # python の virtinstモジュールが入っている必要があります
  my $pid = open2 my $r, my $w, "/usr/bin/python";
  my $python_code = << '__PYTHON__';
import virtinst.util as u
mac = u.randomMAC("qemu")
print mac,
__PYTHON__
  print {$w} $python_code;
  close $w;
  chomp ( my $mac = <$r> );
  $mac =~ /^
              [0-9a-f]{2}:
              [0-9a-f]{2}:
              [0-9a-f]{2}:
              [0-9a-f]{2}:
              [0-9a-f]{2}:
              [0-9a-f]{2}
           $/xms or croak "mac address create failure...";
  return $mac;
}

sub command {
  my $command = shift;
  warn "try command [ $command ]" if is_debug();
  my $r = IPC::Cmd::run(
            command => $command,
            verbose => 1,
            timeout => 30,
          );
  return $r;
}


sub get_api_key {
  my ($self) = @_;

  open my $fh, "<", $self->config->{api_key_file}
    or croak "api key file open error";
  my $api_key_text = do { local $/; <$fh> };
  close $fh;

  # decode できなければ例外だす
  my $ref = decode_json $api_key_text;
  return $ref;

}


sub logger {
  Log::Log4perl::init( $log_config_path );
  my $log = Log::Log4perl->get_logger;
  my $level      = shift;
  my $log_string = shift;
  $log->$level( $log_string );
}


sub remove_set {
  my $disk_path = shift;
  my $config    = config();
  warn "remove disk path: $disk_path" if is_debug();
  if (! -e $disk_path) {
    warn "*** $disk_path is not found";
    return 0;
  }

  my $rename_disk_path = sprintf "%s.%s", $disk_path, $config->{unlink_disk_ext};

  rename $disk_path, $rename_disk_path;
  {
    my $uid = $config->{removed_uid} || 99;
    my $gid = $config->{removed_gid} || 99;
    chown $uid, $gid, $rename_disk_path;
  }

}

1;
