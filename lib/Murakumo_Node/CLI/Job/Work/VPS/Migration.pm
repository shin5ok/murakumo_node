use strict;
use warnings;
use 5.014;

package Murakumo_Node::CLI::Job::Work::VPS::Migration 0.01;

use Carp;
use Data::Dumper;

use FindBin;
use lib qq{$FindBin::Bin/../lib};

sub work {
  my ($self, $job) = @_;

  my $r;

  # 引数をコピー
  my %args = %{$job->arg};

  local $@;
  eval {
    require Murakumo_Node::CLI::VPS;
    my $vps_obj = Murakumo_Node::CLI::VPS->new;

    $r = $vps_obj->migration( \%args );
  };
  if (! $r or $@ ) {
    local $Data::Dumper::Terse = 1;
    my $log = sprintf "migration failed by %s(%s)", Dumper \%args, $@;
    return $job->failed($log);
  }

  $job->completed;
}

1;
