use strict;
use warnings;
package Murakumo_Node::CLI::Job::Work::VPS::Disk::Create;
use Carp;
use Data::Dumper;

use lib qw(/home/smc/Murakumo_Node/lib);
use Murakumo_Node::CLI::VPS::Disk;

# boot部分を作る
sub work {
  my ($self, $job) = @_;

  my $r;

  # 引数をコピー
  my %args = %{$job->arg};
  delete $args{job_uuid};

  local $@;
  eval {
    my $vps_obj = Murakumo_Node::CLI::VPS::Disk->new;

    # disk_param_ref = [
    #                    { path : "/vm/111/uuid.img",    size: 10240 },
    #                    { path : "/vm/111/uuid-01.img", size: 20480 },
    #                  ];

    $r = $vps_obj->create( \%args );
  };
  if (! $r or $@ ) {
    local $Data::Dumper::Terse = 1;
    my $log = sprintf "create failed by %s", Dumper \%args;
    $log .= "($@)";
    $log =~ s/\n/ /g;
    return $job->failed($log);
  }

  $job->completed;
}

1;
