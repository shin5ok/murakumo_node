use strict;
use warnings;
use 5.014;

package Murakumo_Node::CLI::Job::Work::VPS::Boot 0.01;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};

# boot部分を作る
sub work {
  my ($self, $job) = @_;

  my $r;

  # 引数をコピー
  my %args = %{$job->arg};
  delete $args{job_uuid};

  local $@;
  eval {
    require Murakumo_Node::CLI::VPS;
    my $vps_obj = Murakumo_Node::CLI::VPS->new;
    $r = $vps_obj->boot2( \%args );

  };
  if (! $r or $@ ) {
    local $Data::Dumper::Terse = 1;
    my $log = sprintf "boot failed by %s(%s)", Dumper \%args, $@;
    return $job->failed($log);
  }

  $job->completed;
}

1;
