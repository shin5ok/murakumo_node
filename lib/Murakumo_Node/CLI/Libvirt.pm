use warnings;
use strict;
package Murakumo_Node::CLI::Libvirt;

use Sys::Virt;
use Try::Tiny;

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
    # このクラスを継承して、_connect() をオーバーライドすると
    # 楽かも
    if (! $conn or ref $conn ne 'Sys::Virt') {
      warn "libvirt connect";
      $conn = Sys::Virt->new;
    }
  } catch {
    warn "libvirt connection fail exception";
    warn "message: $@" if $_;
    return undef;
  };

  if (! $conn) {
    warn "libvirt connection error";
    return undef;
  }
  return $conn;

}

1;

