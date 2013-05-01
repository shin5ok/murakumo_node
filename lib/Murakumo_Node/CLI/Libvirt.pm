use warnings;
use strict;

package Murakumo_Node::CLI::Libvirt 0.01;

use Sys::Virt;
use Try::Tiny;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::Utils;

our $conn;

sub new {
  my $class = shift;
  bless {
    _conn => _connect(),
  }, $class;
}

sub conn {
  my $self = shift;
  my $conn = $self->{_conn};
  if (my $is_alive = $conn->can("is_alive")) {
    if ($conn->$is_alive) {
      return $conn;
    }
  } else {
    return _connect();
  }
}

sub _connect {
  my $conn;
  local $_;
  try {
    # とりあえず自分のunixドメインのみに接続する
    # livemigrationとかで、他のサーバに接続する必要がある場合は、
    # 接続先を指定できるようにするか、別クラスで対応する
    if (! $conn or ref $conn ne 'Sys::Virt') {
      warn "libvirt connect" if is_debug;
      $conn = Sys::Virt->new;
    }
  } catch {
    warn "libvirt connection fail exception" if is_debug;
    warn "message: $@"                       if is_debug and $_;
    return undef;
  };

  if (! $conn) {
    warn "libvirt connection error";
    return undef;
  }
  return $conn;

}

1;

