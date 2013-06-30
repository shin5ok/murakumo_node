use strict;
use warnings;
use 5.014;

package Murakumo_Node::CLI::Job::Work::VPS::Clone 0.05;
use Carp;
use Data::Dumper;
use FindBin;
use lib qq{$FindBin::Bin/../lib};

# boot部分を作る
sub work {
  my ($self, $job) = @_;

  my $arg = $job->arg;

  no strict 'refs';
  my %param = %$arg;

  my $r;
  local $@;
  eval {
    require Murakumo_Node::CLI::VPS::Disk;
    my $obj = Murakumo_Node::CLI::VPS::Disk->new;
    $r = $obj->clone( \%param );
  };
  if (! $r or $@ ) {
    local $Data::Dumper::Terse = 1;
    my $log = sprintf "clone failed %s(%s)", Dumper $arg, $@;
    return $job->failed($log);
  }

  $job->completed;
}


1;
