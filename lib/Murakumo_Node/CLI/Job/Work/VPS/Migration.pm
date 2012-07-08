use strict;
use warnings;
package Murakumo_Node::CLI::Job::Work::VPS::Migration;
use Carp;
use Data::Dumper;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
use Murakumo_Node::CLI::VPS;

# boot部分を作る
sub work {
  my ($self, $job) = @_;

  my $r;

  # 引数をコピー
  my %args = %{$job->arg};
  delete $args{job_uuid};

  local $@;
  eval {
    my $vps_obj = Murakumo_Node::CLI::VPS->new;
  warn "--- Boot ---";
  warn Dumper \%args;
  warn "------------";

    $r = $vps_obj->migration( \%args );
  };
  if (! $r or $@ ) {
    local $Data::Dumper::Terse = 1;
    my $log = sprintf "migration failed by %s", Dumper \%args;
    $log .= "($@)";
    $log =~ s/\n/ /g;
    return $job->failed($log);
  }

  $job->completed;
}

1;
