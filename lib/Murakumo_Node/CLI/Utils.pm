use strict;
use warnings;
package Murakumo_Node::CLI::Utils;
use URI;
use JSON;
use Data::Dumper;
use Carp;
use HTTP::Request::Common qw/ POST GET /;
use LWP::UserAgent;
use Config::General;
use Sys::Syslog qw(:DEFAULT setlogsock);
use IPC::Open2;

our $VERSION = q(0.0.3);

our $config_path   = q{/home/smc/Murakumo_Node/smc_vps2_node.conf};
our $root_itemname = q{root};

sub import {
  my $caller = caller;
  no strict 'refs';
  *{"${caller}::critical"} = \&critical;
  *{"${caller}::command"}  = \&command;
  *{"${caller}::dumper"}   = \&dumper;

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
  warn "file_path: ", $file_path;
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
  warn "try command [ $command ]";
  my $r = IPC::Cmd::run(
            command => $command,
            verbose => 1,
            timeout => 30,
          );
  return $r;
}


1;
__END__
