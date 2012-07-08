use strict;
use warnings;
package Murakumo_Node::CLI::Job::Work::VPS::Disk::Remove;
use Carp;
use Data::Dumper;

use FindBin;
use lib qq{$FindBin::Bin/../lib};
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

    # disk_ref = [ "/vm/111/uuid.img", "/vm/111/uuid-01.img" ];
    $r = $vps_obj->remove( \%args );
  };
  if (! $r or $@ ) {
    local $Data::Dumper::Terse = 1;
    my $log = sprintf "remove failed by %s", Dumper \%args;
    $log .= "($@)";
    $log =~ s/\n/ /g;
    return $job->failed($log);
  }

  $job->completed;
}

1;
